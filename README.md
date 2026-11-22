# blindfolded

Un-blindfold the blindfolded via a rational Quranic approach — published at [unblindfold.com](https://unblindfold.com).

## Preview (Local / Codespaces)

```bash
quarto preview --port 4200 --host 0.0.0.0 --no-browser
```

## Editing & Custom Tags

### Article Frontmatter

Place essays under `articles/<topic>/` using kebab-case filenames:

```yaml
---
title: "Article Title"
categories: [Concept of God]
order: 1
draft: true # Optional: hides unpublished articles from listings and nav
---
```

### Block Tags

Prefix a paragraph with a tag (or use Quarto fenced divs for multi-paragraph / poetry blocks):

| Tag | Fenced Div Equivalent | Effect |
| :--- | :--- | :--- |
| `@{lead}` | `::: {.lead-para}` | Intro paragraph (larger text, bottom divider) |
| `@{q-trans-en}` | `::: {.q-trans-en}` | Quranic translation (light blue box, blue left border) |
| `@{q-meaning-en}` | `::: {.q-meaning-en}` | Quranic meaning/paraphrase (deeper blue accent) |
| `@{rtl-ar}` | `::: {.rtl-ar lang="ar" dir="rtl"}` | Arabic text (Amiri, RTL right-aligned in a centered cell) |
| `@{rtl-ur}` | `::: {.rtl-ur lang="ur" dir="rtl"}` | Urdu prose (Nastaliq, RTL right-aligned, amber accent) |
| `@{rtl-ur-poetry}` | `::: {.rtl-ur-poetry lang="ur" dir="rtl"}` | Urdu poetry (Nastaliq, RTL centered verses in a centered cell) |
| `@{color-amber}` / `@{amber}` | `::: {.callout-amber}` | Amber callout / poetry translation block |
| `@{maroon}` / `@{quote maroon}` | `::: {.quote-maroon}` | Highlighted maroon quote block |

### Inline Tags & References

| Syntax | Effect |
| :--- | :--- |
| `@ref{Quran 35:19-22}` | Auto-links to `quran.com/35/19-22` in maroon |
| `@ref{Bukhari 1773}` | Auto-links to `sunnah.com/bukhari:1773` |
| `@ref{Muslim 2686}` | Auto-links to `sunnah.com/muslim:2686` |
| `@ref{Tirmidhi N}` / `@ref{Abu Dawud N}` | Auto-links to Sunnah.com |
| `@{qxp\| explanatory note }@` | Smaller muted inline note |
| `@{maroon\| highlighted text }@` | Bold maroon inline emphasis |
| `@{amber\| highlighted text }@` | Bold amber inline emphasis |

### Multi-Line Poetry Example

Use Pandoc line blocks (`|`) inside a fenced div instead of `<br>` so line breaks render cleanly in HTML, PDF, and ePub:

```markdown
::: {.rtl-ur-poetry lang="ur" dir="rtl"}
| لے گئے تثلیث کے فرزند میراثِ خلیل
| خشتِ بنيادِ كليسا بن گئی خاكِ حجاز
:::
```
