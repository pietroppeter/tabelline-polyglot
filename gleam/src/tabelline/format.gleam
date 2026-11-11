//// How the values of a column are written: numbers with decimals and separators, percentages,
//// money, Markdown.
////
//// ```gleam
//// table
//// |> tabelline.format(["diameter"], with: format.integer())
//// |> tabelline.format(["mass"], with: format.number(decimals: 2))
//// |> tabelline.format(["price"], with: format.currency("EUR") |> format.in_locale("it"))
//// ```
////
//// A format only changes how a value is written: the value itself, and what a style or a
//// colour scale reads, stays the number it was.
////

import tabelline/internal/json.{type Json}

/// A way to write the values of a column.
///
pub opaque type Format {
  Format(verb: String, arguments: List(#(String, Json)))
}

/// Whole numbers, with a thousands separator: `142984` is written `142,984`.
///
pub fn integer() -> Format {
  Format("fmtInteger", [])
}

/// Numbers with this many decimals and a thousands separator: `1898.0` with 2 decimals is
/// written `1,898.00`.
///
pub fn number(decimals decimals: Int) -> Format {
  Format("fmtNumber", [#("decimals", json.int(decimals))])
}

/// Numbers as percentages, with this many decimals: `0.25` is written `25.0%`.
///
pub fn percent(decimals decimals: Int) -> Format {
  Format("fmtPercent", [#("decimals", json.int(decimals))])
}

/// Numbers in scientific notation, with this many decimals: `5.97e24` is written `5.97 × 10²⁴`.
///
pub fn scientific(decimals decimals: Int) -> Format {
  Format("fmtScientific", [#("decimals", json.int(decimals))])
}

/// Money, in a currency given by its code: `format.currency("EUR")` writes `1234.5` as
/// `€1,234.50`.
///
pub fn currency(code: String) -> Format {
  Format("fmtCurrency", [#("currency", json.string(code))])
}

/// Text written in Markdown, shown as HTML: `*Solar* System`.
///
pub fn markdown() -> Format {
  Format("fmtMarkdown", [])
}

/// The same format, written the way a locale writes numbers: `"it"` writes `1.234,50`.
///
/// ```gleam
/// format.number(decimals: 2) |> format.in_locale("it")
/// ```
///
pub fn in_locale(format: Format, locale: String) -> Format {
  Format(..format, arguments: [
    #("locale", json.string(locale)),
    ..format.arguments
  ])
}

@internal
pub fn to_verb(format: Format, columns: Json, rows: Json) -> #(String, Json) {
  #(
    format.verb,
    json.object([#("columns", columns), #("rows", rows), ..format.arguments]),
  )
}
