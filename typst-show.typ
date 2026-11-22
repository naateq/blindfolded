// Custom block styling for unblindfold.com PDF exports
#show figure: set block(breakable: true)

#let lead-para(body) = block(
  stroke: (bottom: 0.75pt + rgb("#cbd5e1")),
  inset: (bottom: 10pt),
  below: 14pt,
  width: 100%,
  text(size: 1.08em, fill: rgb("#334155"), body)
)

#let q-trans-en(body) = block(
  fill: rgb("#f8fafc"),
  stroke: (left: 3pt + rgb("#3a68ab")),
  inset: (left: 12pt, right: 10pt, top: 8pt, bottom: 8pt),
  width: 100%,
  text(fill: rgb("#3a68ab"), body)
)

#let q-meaning-en(body) = block(
  fill: rgb("#f1f5f9"),
  stroke: (left: 3pt + rgb("#07457f")),
  inset: (left: 12pt, right: 10pt, top: 8pt, bottom: 8pt),
  width: 100%,
  text(fill: rgb("#07457f"), body)
)

#let callout-amber(body) = block(
  fill: rgb("#fffbeb"),
  stroke: (left: 3pt + rgb("#d97706")),
  inset: (left: 12pt, right: 10pt, top: 8pt, bottom: 8pt),
  width: 100%,
  text(fill: rgb("#9c5606"), body)
)

#let quote-maroon(body) = block(
  fill: rgb("#fdf6f8"),
  stroke: (left: 3pt + rgb("#aa3333")),
  inset: (left: 12pt, right: 10pt, top: 8pt, bottom: 8pt),
  width: 100%,
  text(fill: rgb("#aa3333"), weight: "semibold", body)
)

#let rtl-ar(body) = align(center, block(
  fill: rgb("#f8fafc"),
  stroke: (right: 3pt + rgb("#3a68ab")),
  inset: (left: 14pt, right: 14pt, top: 10pt, bottom: 10pt),
  width: 85%,
  align(right, text(dir: rtl, lang: "ar", size: 1.2em, fill: rgb("#07457f"), body))
))

#let rtl-ur(body) = block(
  fill: rgb("#fffbeb"),
  stroke: (right: 3pt + rgb("#d97706")),
  inset: (left: 10pt, right: 12pt, top: 8pt, bottom: 8pt),
  width: 100%,
  align(right, text(dir: rtl, lang: "ur", size: 1.15em, fill: rgb("#9c5606"), body))
)

#let rtl-ur-poetry(body) = align(center, block(
  fill: rgb("#fffbeb"),
  stroke: (left: 3pt + rgb("#d97706"), right: 3pt + rgb("#d97706")),
  inset: (left: 16pt, right: 16pt, top: 10pt, bottom: 10pt),
  width: 85%,
  align(center, text(dir: rtl, lang: "ur", size: 1.15em, fill: rgb("#9c5606"), body))
))