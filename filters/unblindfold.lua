-- filters/unblindfold.lua
-- Properly 1-indexed Pandoc AST filter for unblindfold.com custom syntax

-- 1. Walk a list of inlines to merge "@ref" + "{Quran 35:19-22}" and handle @{qxp|...}@
local function transform_inlines(inlines)
  local out = pandoc.List()
  local i = 1

  while i <= #inlines do
    local item = inlines[i]

    -- Check for @ref followed by {Citation Text}
    if item.t == "Cite" and item.citations and #item.citations > 0 and item.citations[1].id == "ref" then
      -- Collect following tokens until closing "}"
      if i + 1 <= #inlines and inlines[i + 1].t == "Str" and inlines[i + 1].text:match("^{") then
        local buf = {}
        local j = i + 1
        local found_end = false
        while j <= #inlines do
          local tok = inlines[j]
          local s = pandoc.utils.stringify(tok)
          table.insert(buf, s)
          if tok.t == "Str" and tok.text:match("}$") then
            found_end = true
            break
          end
          j = j + 1
        end

        if found_end then
          local full = table.concat(buf, "")
          full = full:gsub("^{", ""):gsub("}$", "")
          out:insert(pandoc.Span({pandoc.Str("[" .. full .. "]")}, pandoc.Attr("", {"q-ref"})))
          i = j + 1
        else
          out:insert(item)
          i = i + 1
        end
      else
        out:insert(item)
        i = i + 1
      end
    else
      out:insert(item)
      i = i + 1
    end
  end

  -- Second pass: handle @{qxp|...}@, @{maroon|...}@, @{color-amber|...}@ via markdown roundtrip
  local md = pandoc.write(pandoc.Pandoc({pandoc.Plain(out)}), "markdown")
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
    if parsed.blocks and #parsed.blocks > 0 and parsed.blocks[1].content then
      return parsed.blocks[1].content
    end
  end

  return out
end

-- 2. Check if the first inline element of a paragraph is a block-level @tag
local function extract_leading_tag(inlines)
  if #inlines == 0 then return nil, inlines end
  local first = inlines[1]

  -- Case A: Pandoc parsed @{lead} or @{q-trans-en} into a Cite element
  if first.t == "Cite" and first.citations and #first.citations > 0 then
    local id = first.citations[1].id
    if id == "lead" or id == "q-trans-en" or id == "rtl" or id == "rtl-ur" or id == "color-amber" then
      local rest = pandoc.List()
      for idx = 2, #inlines do
        if not (idx == 2 and inlines[idx].t == "Space") then
          rest:insert(inlines[idx])
        end
      end
      return id, rest
    end
  end

  -- Case B: Pandoc kept @{quote maroon} as Str("@{quote") + Space + Str("maroon}")
  if first.t == "Str" and first.text == "@{quote" and #inlines >= 3 then
    if inlines[2].t == "Space" and inlines[3].t == "Str" and inlines[3].text == "maroon}" then
      local rest = pandoc.List()
      for idx = 4, #inlines do
        if not (idx == 4 and inlines[idx].t == "Space") then
          rest:insert(inlines[idx])
        end
      end
      return "quote-maroon", rest
    end
  end

  return nil, inlines
end

-- 3. Process Paragraphs
function Para(el)
  local tag, rest = extract_leading_tag(el.content)
  rest = transform_inlines(rest)

  if tag == "lead" then
    return pandoc.Div({pandoc.Para(rest)}, pandoc.Attr("", {"lead-para"}))
  elseif tag == "q-trans-en" then
    return pandoc.Div({pandoc.Para(rest)}, pandoc.Attr("", {"q-trans-en"}))
  elseif tag == "color-amber" then
    return pandoc.Div({pandoc.Para(rest)}, pandoc.Attr("", {"callout-amber"}))
  elseif tag == "quote-maroon" then
    return pandoc.Div({pandoc.Para(rest)}, pandoc.Attr("", {"quote-maroon"}))
  else
    return pandoc.Para(rest)
  end
end

-- 4. Process BlockQuotes (> @{q-trans-en}, > @{rtl}, > @{rtl-ur}, > @{color-amber})
function BlockQuote(el)
  if #el.content > 0 and el.content[1].t == "Para" then
    local tag, rest = extract_leading_tag(el.content[1].content)
    rest = transform_inlines(rest)

    local new_blocks = pandoc.List({pandoc.Para(rest)})
    for idx = 2, #el.content do
      new_blocks:insert(el.content[idx])
    end

    if tag == "q-trans-en" then
      return pandoc.Div(new_blocks, pandoc.Attr("", {"q-trans-en"}))
    elseif tag == "rtl-ur" then
      return pandoc.Div(new_blocks, pandoc.Attr("", {"rtl-block"}, {lang = "ur", dir = "rtl"}))
    elseif tag == "rtl" then
      return pandoc.Div(new_blocks, pandoc.Attr("", {"rtl-block"}, {dir = "rtl"}))
    elseif tag == "color-amber" then
      return pandoc.Div(new_blocks, pandoc.Attr("", {"callout-amber"}))
    elseif tag == "quote-maroon" then
      return pandoc.Div(new_blocks, pandoc.Attr("", {"quote-maroon"}))
    end
  end
end

-- 5. Process fenced code blocks starting with @{color-amber}
function CodeBlock(el)
  if el.text:match("^@{color%-amber}") then
    local clean = el.text:gsub("^@{color%-amber}%s*", "")
    local parsed = pandoc.read(clean, "markdown")
    return pandoc.Div(parsed.blocks, pandoc.Attr("", {"callout-amber", "poetry-trans"}))
  end
end
