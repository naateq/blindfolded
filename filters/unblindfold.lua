-- filters/unblindfold.lua
-- Universal Pandoc AST filter for unblindfold.com (HTML, Typst PDF, ePub)

local function first_item(list)
  if list and #list > 0 then
    return list[1]
  end
  return nil
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Table of custom block/inline tags used in Markdown
local known_tags = {
  lead = true,
  ["q-trans-en"] = true,
  ["q-meaning-en"] = true,
  rtl = true,
  ["rtl-ur"] = true,
  ["rtl-ur-poetry"] = true,
  ["rtl-ar"] = true,
  ["color-amber"] = true,
  amber = true,
  maroon = true,
}

-- Map tag names to Pandoc Div attributes (classes + HTML/XML attributes)
local tag_to_attr = {
  lead            = pandoc.Attr("", {"lead-para"}),
  ["q-trans-en"]  = pandoc.Attr("", {"q-trans-en"}),
  ["q-meaning-en"]= pandoc.Attr("", {"q-meaning-en"}),
  ["rtl-ar"]      = pandoc.Attr("", {"rtl-ar"}, {lang = "ar", dir = "rtl"}),
  ["rtl-ur"]      = pandoc.Attr("", {"rtl-ur", "rtl-block"}, {lang = "ur", dir = "rtl"}),
  ["rtl-ur-poetry"] = pandoc.Attr("", {"rtl-ur-poetry"}, {lang = "ur", dir = "rtl"}),
  rtl             = pandoc.Attr("", {"rtl-block"}, {dir = "rtl"}),
  ["color-amber"] = pandoc.Attr("", {"callout-amber"}),
  amber           = pandoc.Attr("", {"callout-amber"}),
  maroon          = pandoc.Attr("", {"quote-maroon"}),
}

-- Extensible scripture & Hadith URL registry
local ref_sources = {
  {
    pattern = "^Quran%s+(%d+):(%d+)(%-%d+)?$",
    build_url = function(surah, ayah, range_end)
      return string.format("https://quran.com/%s/%s%s", surah, ayah, range_end or "")
    end,
  },
  {
    pattern = "^Bukhari%s+(%d+)$",
    build_url = function(id) return "https://sunnah.com/bukhari:" .. id end,
  },
  {
    pattern = "^Muslim%s+(%d+)$",
    build_url = function(id) return "https://sunnah.com/muslim:" .. id end,
  },
  {
    pattern = "^Tirmidhi%s+(%d+)$",
    build_url = function(id) return "https://sunnah.com/tirmidhi:" .. id end,
  },
  {
    pattern = "^Abu%s+Dawud%s+(%d+)$",
    build_url = function(id) return "https://sunnah.com/abudawud:" .. id end,
  },
}

-- Classes that map directly to #let functions in typst-show.typ
local typst_block_classes = {
  "q-trans-en",
  "q-meaning-en",
  "lead-para",
  "callout-amber",
  "quote-maroon",
  "rtl-ar",
  "rtl-ur",
  "rtl-ur-poetry",
}

local function parse_ref_element(inside_text)
  local cleaned = trim(inside_text or "")
  for _, src in ipairs(ref_sources) do
    local matches = {cleaned:match(src.pattern)}
    if #matches > 0 then
      local url = src.build_url(table.unpack(matches))
      return pandoc.Link({pandoc.Str("[" .. cleaned .. "]")}, url, "", pandoc.Attr("", {"q-ref"}))
    end
  end

  -- Fallback: styled maroon span for non-linked references
  return pandoc.Span({pandoc.Str("[" .. cleaned .. "]")}, pandoc.Attr("", {"q-ref"}))
end

local function transform_inlines(inlines)
  local merged = pandoc.List()
  local i = 1

  while i <= #inlines do
    local item = inlines[i]
    local first_cite = (item.t == "Cite") and first_item(item.citations) or nil

    -- Case 1: @ref followed by {Citation Text}
    if first_cite and first_cite.id == "ref" then
      if i + 1 <= #inlines and inlines[i + 1].t == "Str" and inlines[i + 1].text:match("^{") then
        local buf = {}
        local j = i + 1
        local found_end = false
        while j <= #inlines do
          local tok = inlines[j]
          table.insert(buf, pandoc.utils.stringify(tok))
          if tok.t == "Str" and tok.text:match("}") then
            found_end = true
            break
          end
          j = j + 1
        end
        if found_end then
          local full = table.concat(buf, "")
          local inside, after = full:match("^{(.-)}(.*)$")
          merged:insert(parse_ref_element(inside or full))
          if after and after ~= "" then
            merged:insert(pandoc.Str(after))
          end
          i = j + 1
        else
          i = i + 1
        end
      else
        i = i + 1
      end

    -- Case 2: Repeated/inline known custom tag (e.g., second line of a tagged blockquote)
    elseif first_cite and known_tags[first_cite.id] then
      if i + 1 <= #inlines and inlines[i + 1].t == "Space" then
        i = i + 2
      else
        i = i + 1
      end

    -- Case 3: Inline @{tag| content }@
    elseif item.t == "Str" and item.text:match("^@{([%w%-]+)|") then
      local tag_name, first_part = item.text:match("^@{([%w%-]+)|(.*)$")
      local inner_inlines = pandoc.List()

      if first_part ~= "" and first_part:match("}") then
        local before, after = first_part:match("^(.-)}@?(.*)$")
        if before ~= "" then inner_inlines:insert(pandoc.Str(before)) end
        merged:insert(pandoc.Span(inner_inlines, pandoc.Attr("", {tag_name})))
        if after ~= "" then merged:insert(pandoc.Str(after)) end
        i = i + 1
      else
        if first_part ~= "" then inner_inlines:insert(pandoc.Str(first_part)) end
        local j = i + 1
        local closed = false
        while j <= #inlines do
          local tok = inlines[j]
          if tok.t == "Cite" then
            break
          elseif tok.t == "Str" and tok.text:match("}") then
            local before, after = tok.text:match("^(.-)}@?(.*)$")
            if before ~= "" then inner_inlines:insert(pandoc.Str(before)) end
            merged:insert(pandoc.Span(inner_inlines, pandoc.Attr("", {tag_name})))
            if after ~= "" then merged:insert(pandoc.Str(after)) end
            closed = true
            break
          else
            inner_inlines:insert(tok)
          end
          j = j + 1
        end
        if closed then
          i = j + 1
        else
          merged:insert(pandoc.Span(inner_inlines, pandoc.Attr("", {tag_name})))
          i = j
        end
      end

    -- Preserve all other tokens (including real future BibTeX/CSL citations)
    else
      merged:insert(item)
      i = i + 1
    end
  end

  return merged
end

local function extract_leading_tag(inlines)
  local first = first_item(inlines)
  if not first then return nil, inlines end

  local first_cite = (first.t == "Cite") and first_item(first.citations) or nil
  if first_cite and known_tags[first_cite.id] then
    local rest = pandoc.List()
    for idx = 2, #inlines do
      if not (idx == 2 and inlines[idx].t == "Space") then
        rest:insert(inlines[idx])
      end
    end
    return first_cite.id, rest
  end

  if first.t == "Str" and first.text == "@{quote" and #inlines >= 3 then
    if inlines[2].t == "Space" and inlines[3].t == "Str" and inlines[3].text == "maroon}" then
      local rest = pandoc.List()
      for idx = 4, #inlines do
        if not (idx == 4 and inlines[idx].t == "Space") then
          rest:insert(inlines[idx])
        end
      end
      return "maroon", rest
    end
  end

  return nil, inlines
end

-- Pass 1: Convert tagged BlockQuotes and CodeBlocks before Para runs
local function handle_blockquote(el)
  local first_block = first_item(el.content)
  if first_block and first_block.t == "Para" then
    local tag, rest = extract_leading_tag(first_block.content)
    local attr = tag and tag_to_attr[tag] or nil
    if attr then
      local new_blocks = pandoc.List({pandoc.Para(rest)})
      for idx = 2, #el.content do
        new_blocks:insert(el.content[idx])
      end
      return pandoc.Div(new_blocks, attr)
    end
  end
end

local function handle_codeblock(el)
  if el.text:match("^@{color%-amber}") then
    local clean = el.text:gsub("^@{color%-amber}%s*", "")
    local parsed = pandoc.read(clean, "markdown")
    return pandoc.Div(parsed.blocks, pandoc.Attr("", {"callout-amber", "poetry-trans"}))
  end
end

-- Pass 2: Convert tagged top-level Paragraphs and transform all inlines
local function handle_para(el)
  local tag, rest = extract_leading_tag(el.content)
  rest = transform_inlines(rest)
  local attr = tag and tag_to_attr[tag] or nil
  if attr then
    return pandoc.Div({pandoc.Para(rest)}, attr)
  end
  return pandoc.Para(rest)
end

local function handle_plain(el)
  return pandoc.Plain(transform_inlines(el.content))
end

local function handle_cite(el)
  local raw = pandoc.utils.stringify(el)
  local inside = raw:match("@ref{(.-)}")
  if inside then
    return parse_ref_element(inside)
  end
  return el
end

-- Pass 3: Wire semantic Div classes into typst-show.typ when rendering Typst PDF
local function render_div_for_typst(el)
  if not FORMAT:match("typst") then
    return nil
  end
  for _, cls in ipairs(typst_block_classes) do
    if el.classes:includes(cls) then
      local blocks = pandoc.List({pandoc.RawBlock("typst", "#" .. cls .. "[")})
      blocks:extend(el.content)
      blocks:insert(pandoc.RawBlock("typst", "]"))
      return blocks
    end
  end
end

return {
  { BlockQuote = handle_blockquote, CodeBlock = handle_codeblock },
  { Para = handle_para, Plain = handle_plain, Cite = handle_cite },
  { Div = render_div_for_typst },
}
