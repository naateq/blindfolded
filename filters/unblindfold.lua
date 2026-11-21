-- filters/unblindfold.lua
-- Converts custom unblindfold.com syntax into clean HTML/PDF/EPUB elements

local function convert_inline_patterns(text)
  -- 1. Convert @{qxp| ... }@ explanatory glosses
  text = text:gsub("@{qxp|%s*(.-)%s*}@", '<span class="qxp">%1</span>')
  -- 2. Convert @{maroon| ... }@ inline highlights
  text = text:gsub("@{maroon|%s*(.-)%s*}@", '<span class="text-maroon">%1</span>')
  -- 3. Convert @ref{...} citations
  text = text:gsub("@ref{(.-)}", '<span class="q-ref">[%1]</span>')
  return text
end

function Para(el)
  local raw = pandoc.utils.stringify(el)

  -- Handle block-level @{q-trans-en} paragraphs
  if raw:match("^@{q%-trans%-en}") then
    local html = pandoc.write(pandoc.Pandoc({el}), "html")
    html = html:gsub("^<p>@{q%-trans%-en}%s*", '<div class="q-trans-en"><p>')
    html = html:gsub("</p>%s*$", "</p></div>")
    html = convert_inline_patterns(html)
    return pandoc.RawBlock("html", html)
  end

  -- Handle block-level @{quote maroon} paragraphs
  if raw:match("^@{quote%s+maroon}") then
    local html = pandoc.write(pandoc.Pandoc({el}), "html")
    html = html:gsub("^<p>@{quote%s+maroon}%s*", '<blockquote class="quote-maroon"><p>')
    html = html:gsub("</p>%s*$", "</p></blockquote>")
    html = convert_inline_patterns(html)
    return pandoc.RawBlock("html", html)
  end

  -- Handle standard paragraphs containing inline @ref, @{qxp|}, or @{maroon|}
  if raw:match("@ref{") or raw:match("@{qxp|") or raw:match("@{maroon|") then
    local html = pandoc.write(pandoc.Pandoc({el}), "html")
    html = convert_inline_patterns(html)
    return pandoc.RawBlock("html", html)
  end
end
