-- filters/unblindfold.lua
-- Automatically converts custom unblindfold.com tags across HTML, PDF, and EPUB

local function convert_inline(text)
  -- Explanatory translator notes: @{qxp| ... }@
  text = text:gsub("@{qxp|%s*(.-)%s*}@", '<span class="qxp">%1</span>')
  -- Inline maroon highlight: @{maroon| ... }@
  text = text:gsub("@{maroon|%s*(.-)%s*}@", '<span class="text-maroon">%1</span>')
  -- Inline amber highlight: @{color-amber| ... }@
  text = text:gsub("@{color%-amber|%s*(.-)%s*}@", '<span class="text-amber">%1</span>')
  -- Scripture references: @ref{Quran 112:1-4}
  text = text:gsub("@ref{(.-)}", '<span class="q-ref">[%1]</span>')
  return text
end

-- 1. Handle fenced code blocks starting with @{color-amber} (e.g., poetry translations)
function CodeBlock(el)
  if el.text:match("^@{color%-amber}") then
    local clean = el.text:gsub("^@{color%-amber}%s*", "")
    clean = clean:gsub("\n", "<br>\n")
    return pandoc.RawBlock("html", '<div class="callout-amber poetry-trans">' .. clean .. '</div>')
  end
end

-- 2. Handle blockquotes starting with @{rtl}, @{rtl-ur}, @{color-amber}, or @{quote maroon}
function BlockQuote(el)
  local raw = pandoc.utils.stringify(el)
  local html = pandoc.write(pandoc.Pandoc(el.content), "html")
  html = convert_inline(html)

  if raw:match("^@{rtl%-ur}") then
    html = html:gsub("@{rtl%-ur}%s*", "")
    return pandoc.RawBlock("html", '<div class="rtl-block" lang="ur" dir="rtl">' .. html .. '</div>')
  elseif raw:match("^@{rtl}") then
    html = html:gsub("@{rtl}%s*", "")
    return pandoc.RawBlock("html", '<div class="rtl-block" dir="rtl">' .. html .. '</div>')
  elseif raw:match("^@{color%-amber}") then
    html = html:gsub("@{color%-amber}%s*", "")
    return pandoc.RawBlock("html", '<div class="callout-amber">' .. html .. '</div>')
  elseif raw:match("^@{quote%s+maroon}") then
    html = html:gsub("@{quote%s+maroon}%s*", "")
    return pandoc.RawBlock("html", '<blockquote class="quote-maroon">' .. html .. '</blockquote>')
  end
end

-- 3. Handle standard paragraphs with @{q-trans-en}, @{quote maroon}, or inline tags
function Para(el)
  local raw = pandoc.utils.stringify(el)
  local html = pandoc.write(pandoc.Pandoc({el}), "html")
  html = convert_inline(html)

  if raw:match("^@{q%-trans%-en}") then
    html = html:gsub("^<p>@{q%-trans%-en}%s*", '<div class="q-trans-en"><p>')
    html = html:gsub("</p>%s*$", "</p></div>")
    return pandoc.RawBlock("html", html)
  elseif raw:match("^@{quote%s+maroon}") then
    html = html:gsub("^<p>@{quote%s+maroon}%s*", '<blockquote class="quote-maroon"><p>')
    html = html:gsub("</p>%s*$", "</p></blockquote>")
    return pandoc.RawBlock("html", html)
  elseif raw:match("@ref{") or raw:match("@{qxp|") or raw:match("@{maroon|") or raw:match("@{color%-amber|") then
    return pandoc.RawBlock("html", html)
  end
end
