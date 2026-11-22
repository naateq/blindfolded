-- filters/unblindfold.lua
-- Universal Pandoc AST filter for unblindfold.com (HTML, Typst PDF, ePub)

-- Helper: Parse inline custom tags (@{qxp|...}, @{maroon|...}, @{color-amber|...}, @ref{...})
local function transform_inlines(inlines)
  -- First, convert the inline list to raw string tokens where needed, or walk tokens directly
  local merged = pandoc.List()
  local i = 1

  while i <= #inlines do
    local item = inlines[i]

    -- 1. Handle @ref followed by {Citation Text}
    if item.t == "Cite" and item.citations and #item.citations > 0 and item.citations.id == "ref" then
      if i + 1 <= #inlines and inlines[i + 1].t == "Str" and inlines[i + 1].text:match("^{") then
        local buf = {}
        local j = i + 1
        local found_end = false
        while j <= #inlines do
          local tok = inlines[j]
          table.insert(buf, pandoc.utils.stringify(tok))
          if tok.t == "Str" and tok.text:match("}$") then
            found_end = true
            break
          end
          j = j + 1
        end
        if found_end then
          local full = table.concat(buf, ""):gsub("^{", ""):gsub("}$", "")
          merged:insert(pandoc.Span({pandoc.Str("[" .. full .. "]")}, pandoc.Attr("", {"q-ref"})))
          i = j + 1
        else
          merged:insert(item)
          i = i + 1
        end
      else
        merged:insert(item)
        i = i + 1
      end

    -- 2. Handle inline @{tag| content }@ or @{tag| content } across multiple tokens
    elseif item.t == "Str" and item.text:match("^@{([%w%-]+)|") then
      local tag_name, first_part = item.text:match("^@{([%w%-]+)|(.*)$")
      local inner_inlines = pandoc.List()
      if first_part ~= "" then
        -- Check if closing } or }@ is already in the very same Str token
        if first_part:match("}@?$") then
          local clean = first_part:gsub("}@?$", "")
          inner_inlines:insert(pandoc.Str(clean))
          merged:insert(pandoc.Span(inner_inlines, pandoc.Attr("", {tag_name})))
          i = i + 1
        else
          inner_inlines:insert(pandoc.Str(first_part))
          local j = i + 1
          local closed = false
          while j <= #inlines do
            local tok = inlines[j]
            if tok.t == "Str" and tok.text:match("}@?$") then
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
            merged:insert(item)
            i = i + 1
          end
        end
      else
        -- "@{qxp|" followed by Space and text until "}@" or "}"
        local j = i + 1
        local closed = false
        while j <= #inlines do
          local tok = inlines[j]
          if tok.t == "Str" and tok.text:match("}@?$") then
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
          merged:insert(item)
          i = i + 1
        end
      end
    else
      merged:insert(item)
      i = i + 1
    end
  end

  return merged
end

-- Handle @ref{...} when nested inside square brackets [...]
function Cite(el)
  local raw = pandoc.utils.stringify(el)
  if raw:match("@ref{.-}") then
    local replaced = raw:gsub("@ref{(.-)}", "[%1]")
    return pandoc.Span({pandoc.Str(replaced)}, pandoc.Attr("", {"q-ref"}))
  end
end

-- Check leading block-level @tag on paragraphs/blockquotes
local function extract_leading_tag(inlines)
  if #inlines == 0 then return nil, inlines end
  local first = inlines

  if first.t == "Cite" and first.citations and #first.citations > 0 then
    local id = first.citations.id
    local valid = {
      lead = true, ["q-trans-en"] = true, ["q-meaning-en"] = true,
      rtl = true, ["rtl-ur"] = true, ["color-amber"] = true,
      amber = true, maroon = true
    }
    if valid[id] then
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
    if inlines.t == "Space" and inlines.t == "Str" and inlines.text == "maroon}" then
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
  elseif tag == "color-amber" or tag == "amber" then
    return pandoc.Div({pandoc.Para(rest)}, pandoc.Attr("", {"callout-amber"}))
  elseif tag == "maroon" then
    return pandoc.Div({pandoc.Para(rest)}, pandoc.Attr("", {"quote-maroon"}))
  else
    return pandoc.Para(rest)
  end
end

function BlockQuote(el)
  if #el.content > 0 and el.content.t == "Para" then
    local tag, rest = extract_leading_tag(el.content.content)
    rest = transform_inlines(rest)

    local new_blocks = pandoc.List({pandoc.Para(rest)})
    for idx = 2, #el.content do
      new_blocks:insert(el.content[idx])
    end

    if tag == "q-trans-en" then
      return pandoc.Div(new_blocks, pandoc.Attr("", {"q-trans-en"}))
    elseif tag == "q-meaning-en" then
      return pandoc.Div(new_blocks, pandoc.Attr("", {"q-meaning-en"}))
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
