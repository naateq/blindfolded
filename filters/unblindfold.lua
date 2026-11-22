-- filters/unblindfold.lua
-- Universal Pandoc AST filter for unblindfold.com (HTML, Typst PDF, ePub)

local function first_item(list)
  if list and #list > 0 then
    return select(1, table.unpack(list))
  end
  return nil
end

-- Table of all custom tags used in Markdown (@lead, @rtl-ar, @rtl-ur, etc.)
local known_tags = {
  lead = true,
  ["q-trans-en"] = true,
  ["q-meaning-en"] = true,
  rtl = true,
  ["rtl-ur"] = true,
  ["rtl-ar"] = true,
  ["color-amber"] = true,
  amber = true,
  maroon = true
}

-- Parse scripture and Hadith references to build hyperlinked or styled nodes
local function parse_ref_element(inside_text)
  -- Quran reference: e.g. "Quran 43:22" or "Quran 43:22-25"
  local surah, ayah = inside_text:match("^Quran%s+(%d+):(%d+)")
  if surah and ayah then
    local url = string.format("https://quran.com/%s/%s", surah, ayah)
    return pandoc.Link({pandoc.Str("[" .. inside_text .. "]")}, url, "", pandoc.Attr("", {"q-ref"}))
  end

  -- Bukhari Hadith: e.g. "Bukhari 1773"
  local bukhari_id = inside_text:match("^Bukhari%s+(%d+)")
  if bukhari_id then
    local url = string.format("https://sunnah.com/bukhari:%s", bukhari_id)
    return pandoc.Link({pandoc.Str("[" .. inside_text .. "]")}, url, "", pandoc.Attr("", {"q-ref"}))
  end

  -- Muslim Hadith: e.g. "Muslim 2686"
  local muslim_id = inside_text:match("^Muslim%s+(%d+)")
  if muslim_id then
    local url = string.format("https://sunnah.com/muslim:%s", muslim_id)
    return pandoc.Link({pandoc.Str("[" .. inside_text .. "]")}, url, "", pandoc.Attr("", {"q-ref"}))
  end

  -- Fallback: Styled maroon span
  return pandoc.Span({pandoc.Str("[" .. inside_text .. "]")}, pandoc.Attr("", {"q-ref"}))
end

local function transform_inlines(inlines)
  local merged = pandoc.List()
  local i = 1

  while i <= #inlines do
    local item = inlines[i]

    -- Case 1: @ref followed by {Citation Text}
    local first_cite = (item.t == "Cite") and first_item(item.citations) or nil
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
          merged:insert(pandoc.Str(""))
          i = i + 1
        end
      else
        merged:insert(pandoc.Str(""))
        i = i + 1
      end

    -- Case 2: Stray Cite object (@rtl-ar, @rtl-ur, @q-trans-en, @lead, @maroon, @amber, etc.)
    elseif first_cite then
      local id = first_cite.id
      if known_tags[id] then
        if i + 1 <= #inlines and inlines[i + 1].t == "Space" then
          i = i + 2
        else
          i = i + 1
        end
      else
        -- Consume stray cite nodes so they don't leak to Typst bibliography
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
    else
      merged:insert(item)
      i = i + 1
    end
  end

  return merged
end

function Cite(el)
  local raw = pandoc.utils.stringify(el)
  if raw:match("@ref{.-}") then
    local inside = raw:match("@ref{(.-)}")
    return parse_ref_element(inside)
  end

  -- Intercept any remaining Cite elements to prevent Typst bibliography errors
  return pandoc.Str("")
end

local function extract_leading_tag(inlines)
  local first = first_item(inlines)
  if not first then return nil, inlines end

  local first_cite = (first.t == "Cite") and first_item(first.citations) or nil
  if first_cite then
    local id = first_cite.id
    if known_tags[id] then
      local rest = pandoc.List()
      for idx = 2, #inlines do
        if not (idx == 2 and inlines[idx].t == "Space") then
          rest:insert(inlines[idx])
        end
      end
      return id, rest
    end
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

function Para(el)
  local tag, rest = extract_leading_tag(el.content)
  rest = transform_inlines(rest)

  if tag == "lead" then
    return pandoc.Div({pandoc.Para(rest)}, pandoc.Attr("", {"lead-para"}))
  elseif tag == "q-trans-en" then
    return pandoc.Div({pandoc.Para(rest)}, pandoc.Attr("", {"q-trans-en"}))
  elseif tag == "q-meaning-en" then
    return pandoc.Div({pandoc.Para(rest)}, pandoc.Attr("", {"q-meaning-en"}))
  elseif tag == "rtl-ar" then
    return pandoc.Div({pandoc.Para(rest)}, pandoc.Attr("", {"rtl-block"}, {lang = "ar", dir = "rtl"}))
  elseif tag == "rtl-ur" then
    return pandoc.Div({pandoc.Para(rest)}, pandoc.Attr("", {"rtl-block"}, {lang = "ur", dir = "rtl"}))
  elseif tag == "rtl" then
    return pandoc.Div({pandoc.Para(rest)}, pandoc.Attr("", {"rtl-block"}, {dir = "rtl"}))
  elseif tag == "color-amber" or tag == "amber" then
    return pandoc.Div({pandoc.Para(rest)}, pandoc.Attr("", {"callout-amber"}))
  elseif tag == "maroon" then
    return pandoc.Div({pandoc.Para(rest)}, pandoc.Attr("", {"quote-maroon"}))
  else
    return pandoc.Para(rest)
  end
end

function Plain(el)
  return pandoc.Plain(transform_inlines(el.content))
end

function BlockQuote(el)
  local first_block = first_item(el.content)
  if first_block and first_block.t == "Para" then
    local tag, rest = extract_leading_tag(first_block.content)
    rest = transform_inlines(rest)

    local new_blocks = pandoc.List({pandoc.Para(rest)})
    for idx = 2, #el.content do
      new_blocks:insert(el.content[idx])
    end

    if tag == "q-trans-en" then
      return pandoc.Div(new_blocks, pandoc.Attr("", {"q-trans-en"}))
    elseif tag == "q-meaning-en" then
      return pandoc.Div(new_blocks, pandoc.Attr("", {"q-meaning-en"}))
    elseif tag == "rtl-ar" then
      return pandoc.Div(new_blocks, pandoc.Attr("", {"rtl-block"}, {lang = "ar", dir = "rtl"}))
    elseif tag == "rtl-ur" then
      return pandoc.Div(new_blocks, pandoc.Attr("", {"rtl-block"}, {lang = "ur", dir = "rtl"}))
    elseif tag == "rtl" then
      return pandoc.Div(new_blocks, pandoc.Attr("", {"rtl-block"}, {dir = "rtl"}))
    elseif tag == "color-amber" or tag == "amber" then
      return pandoc.Div(new_blocks, pandoc.Attr("", {"callout-amber"}))
    elseif tag == "maroon" then
      return pandoc.Div(new_blocks, pandoc.Attr("", {"quote-maroon"}))
    end
  end
end

function CodeBlock(el)
  if el.text:match("^@{color%-amber}") then
    local clean = el.text:gsub("^@{color%-amber}%s*", "")
    local parsed = pandoc.read(clean, "markdown")
    return pandoc.Div(parsed.blocks, pandoc.Attr("", {"callout-amber", "poetry-trans"}))
  end
end
