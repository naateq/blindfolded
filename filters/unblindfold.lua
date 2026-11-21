-- filters/unblindfold.lua
-- Intercepts Pandoc Cite (@lead, @q-trans-en, @ref) and custom @{...} syntax

-- 1. Convert inline @ref{...}, @{qxp|...}@, @{maroon|...}@, @{color-amber|...}@
function Cite(el)
  local id = el.citations and el.citations.id or ""

  -- Handle @ref{Quran 35:19-22} -> Pandoc parses @ref + suffix {Quran 35:19-22}
  if id == "ref" then
    local suffix_text = pandoc.utils.stringify(el.content)
    -- Extract text inside { ... } if present
    local ref_label = suffix_text:match("^{(.-)}") or suffix_text:gsub("^@ref", "")
    ref_label = ref_label:gsub("^{", ""):gsub("}$", "")
    if ref_label ~= "" then
      return pandoc.Span({pandoc.Str("[" .. ref_label .. "]")}, pandoc.Attr("", {"q-ref"}))
    end
  end
end

-- Helper: Check if a paragraph starts with @lead, @q-trans-en, or @quote
local function check_prefix_cite(inlines)
  if #inlines == 0 then return nil, inlines end
  local first = inlines

  if first.t == "Cite" and first.citations and #first.citations > 0 then
    local id = first.citations.id
    if id == "lead" or id == "q-trans-en" or id == "rtl" or id == "rtl-ur" or id == "color-amber" then
      local rest = pandoc.List()
      for i = 2, #inlines do
        -- Skip leading Space right after the tag
        if not (i == 2 and inlines[i].t == "Space") then
          rest:insert(inlines[i])
        end
      end
      return id, rest
    end
  end
  return nil, inlines
end

-- Helper: Replace inline @{qxp|...}@, @{maroon|...}@, @{color-amber|...}@ inside Str tokens
local function transform_inline_braces(inlines)
  local md = pandoc.write(pandoc.Pandoc({pandoc.Plain(inlines)}), "markdown")
  local changed = false

  if md:match("@{qxp|") then
    md = md:gsub("\\?@{qxp|%s*(.-)%s*\\?}@", '[%1]{.qxp}')
    changed = true
  end
  if md:match("@{maroon|") then
    md = md:gsub("\\?@{maroon|%s*(.-)%s*\\?}@", '[%1]{.text-maroon}')
    changed = true
  end
  if md:match("@{color%-amber|") then
    md = md:gsub("\\?@{color%-amber|%s*(.-)%s*\\?}@", '[%1]{.text-amber}')
    changed = true
  end

  if changed then
    local parsed = pandoc.read(md, "markdown")
    if parsed.blocks and parsed.blocks.content then
      return parsed.blocks.content
    end
  end
  return inlines
end

-- 2. Handle Paragraphs starting with @lead, @q-trans-en, etc.
function Para(el)
  local tag, rest = check_prefix_cite(el.content)
  rest = transform_inline_braces(rest)

  if tag == "lead" then
    return pandoc.Div({pandoc.Para(rest)}, pandoc.Attr("", {"lead-para"}))
  elseif tag == "q-trans-en" then
    return pandoc.Div({pandoc.Para(rest)}, pandoc.Attr("", {"q-trans-en"}))
  elseif tag == "color-amber" then
    return pandoc.Div({pandoc.Para(rest)}, pandoc.Attr("", {"callout-amber"}))
  else
    return pandoc.Para(rest)
  end
end

-- 3. Handle BlockQuotes starting with > @{q-trans-en}, > @{rtl}, > @{rtl-ur}, > @{color-amber}
function BlockQuote(el)
  if #el.content > 0 and el.content.t == "Para" then
    local tag, rest = check_prefix_cite(el.content.content)
    rest = transform_inline_braces(rest)

    local new_blocks = pandoc.List({pandoc.Para(rest)})
    for i = 2, #el.content do
      new_blocks:insert(el.content[i])
    end

    if tag == "q-trans-en" then
      return pandoc.Div(new_blocks, pandoc.Attr("", {"q-trans-en"}))
    elseif tag == "rtl-ur" then
      return pandoc.Div(new_blocks, pandoc.Attr("", {"rtl-block"}, {lang = "ur", dir = "rtl"}))
    elseif tag == "rtl" then
      return pandoc.Div(new_blocks, pandoc.Attr("", {"rtl-block"}, {dir = "rtl"}))
    elseif tag == "color-amber" then
      return pandoc.Div(new_blocks, pandoc.Attr("", {"callout-amber"}))
    end
  end
end

-- 4. Handle fenced code blocks starting with @{color-amber}
function CodeBlock(el)
  if el.text:match("^@{color%-amber}") then
    local clean = el.text:gsub("^@{color%-amber}%s*", "")
    local parsed = pandoc.read(clean, "markdown")
    return pandoc.Div(parsed.blocks, pandoc.Attr("", {"callout-amber", "poetry-trans"}))
  end
end
