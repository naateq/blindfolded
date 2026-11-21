// Custom block styling for unblindfold.com PDF exports
#show figure: set block(breakable: true)

// Style Quranic translation blocks, amber callouts, and maroon quotes
#let q-trans-en(body) = block(
  fill: rgb("#f8fafc"),
  stroke: (left: 3pt + rgb("#2c5282")),
  inset: (left: 12pt, right: 10pt, top: 8pt, bottom: 8pt),
  width: 100%,
  body
)

#let callout-amber(body) = block(
  fill: rgb("#fffbeb"),
  stroke: (left: 3pt + rgb("#d97706")),
  inset: (left: 12pt, right: 10pt, top: 8pt, bottom: 8pt),
  width: 100%,
  body
)

#let quote-maroon(body) = block(
  fill: rgb("#fdf6f8"),
  stroke: (left: 3pt + rgb("#800020")),
  inset: (left: 12pt, right: 10pt, top: 8pt, bottom: 8pt),
  width: 100%,
  body
)
