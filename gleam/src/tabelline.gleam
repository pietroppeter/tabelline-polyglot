//// 📊 Great tables for Gleam: display tables built from parts, formatted and styled, written
//// as HTML, text or Markdown.
////
//// A table starts from a list of your own records; then each step adds one thing, with `|>`:
//// a column, a title, a label, a format, a style, a note.
////
//// ```gleam
//// import tabelline.{Plain}
//// import tabelline/column
//// import tabelline/format
////
//// pub type Planet {
////   Planet(name: String, diameter: Int, mass: Float)
//// }
////
//// pub fn main() {
////   let assert Ok(html) =
////     [Planet("Mercury", 4879, 0.33), Planet("Venus", 12_104, 4.87)]
////     |> tabelline.from_list
////     |> column.string("planet", fn(planet) { planet.name })
////     |> column.int("diameter", fn(planet) { planet.diameter })
////     |> column.float("mass", fn(planet) { planet.mass })
////     |> tabelline.stub("planet")
////     |> tabelline.title(Plain("The planets"))
////     |> tabelline.format(["mass"], with: format.number(decimals: 2))
////     |> tabelline.to_html
//// }
//// ```
////
//// Nothing is drawn until `to_html`, `to_text` or `to_markdown`: until then a table is a plain
//// Gleam value, and you can pass it around, keep it, and add to it. The drawing is done by
//// [tabelline](https://github.com/pietroppeter/tabelline), a Nim library, which reads the
//// table as JSON; on the BEAM it is called through a NIF.
////

import tabelline/format.{type Format}
import tabelline/internal/json.{type Json}
import tabelline/internal/table.{Header, NoHeader, Table}
import tabelline/location.{type Location}
import tabelline/rows
import tabelline/style.{type Style}

// --- TYPES -------------------------------------------------------------------

/// A table of rows of type `row`, ready to be drawn or to get one more step.
///
pub type Table(row) =
  table.Table(row)

/// Text in a title, a label or a note: plain, or written in Markdown or HTML.
///
pub type Text {
  Plain(String)
  Markdown(String)
  Html(String)
}

/// The colours a colour scale goes through, from the lowest value to the highest.
///
pub type Palette {
  Blues
  Greens
  Reds
  Viridis
  /// Red, white and blue: for values around a middle.
  RedBlue
  /// Red, yellow and green.
  RedYellowGreen
  /// Any colours, as CSS colours: `Colours(["#ffffff", "#2171b5"])`.
  Colours(List(String))
}

/// What a summary row computes over the rows above it.
///
pub type Aggregate {
  Sum
  Mean
  Median
  Min
  Max
  Count
  StandardDeviation
}

/// Why a table could not be drawn.
///
pub type Error {
  /// Two columns have the same name.
  DuplicateColumn(name: String)
  /// tabelline itself refused the table: a step names a column the table does not have, or
  /// gives a value it cannot use. The reason says which.
  Rejected(reason: String)
}

// --- BUILDING A TABLE --------------------------------------------------------

/// A table of these rows, still with no columns: add them with the functions of
/// `tabelline/column`, in the order they are shown.
///
/// ```gleam
/// planets
/// |> tabelline.from_list
/// |> column.string("planet", fn(planet) { planet.name })
/// |> column.int("moons", fn(planet) { planet.moons })
/// ```
///
pub fn from_list(rows: List(row)) -> Table(row) {
  Table(rows:, columns: [], settings: [], header: NoHeader, verbs: [])
}

/// The stub: the column whose values name the rows, shown first and set apart.
///
/// ```gleam
/// table |> tabelline.stub("planet")
/// ```
///
pub fn stub(table: Table(row), column: String) -> Table(row) {
  setting(table, "rownameCol", json.string(column))
}

/// The column whose values group the rows: each group gets its own label, in the order the
/// groups first appear.
///
/// ```gleam
/// table |> tabelline.group_by("type")
/// ```
///
pub fn group_by(table: Table(row), column: String) -> Table(row) {
  setting(table, "groupnameCol", json.string(column))
}

/// The table's HTML id, for a page that styles or links it.
///
pub fn id(table: Table(row), id: String) -> Table(row) {
  setting(table, "id", json.string(id))
}

/// The locale every format uses, unless it has its own: `"it"`, `"de"`, `"en-GB"`.
///
pub fn locale(table: Table(row), locale: String) -> Table(row) {
  setting(table, "locale", json.string(locale))
}

// --- THE HEADER AND THE FOOTER -----------------------------------------------

/// The title, above the table.
///
/// ```gleam
/// table |> tabelline.title(Plain("The planets"))
/// ```
///
pub fn title(table: Table(row), title: Text) -> Table(row) {
  case table.header {
    NoHeader ->
      Table(..table, header: Header(text(title), subtitle: Error(Nil)))
    Header(..) as header ->
      Table(..table, header: Header(..header, title: text(title)))
  }
}

/// The subtitle, under the title. A table with a subtitle needs a title too.
///
/// ```gleam
/// table
/// |> tabelline.title(Plain("The planets"))
/// |> tabelline.subtitle(Markdown("of the *Solar System*"))
/// ```
///
pub fn subtitle(table: Table(row), subtitle: Text) -> Table(row) {
  let title = case table.header {
    NoHeader -> json.string("")
    Header(title:, ..) -> title
  }
  Table(..table, header: Header(title:, subtitle: Ok(text(subtitle))))
}

/// A note at the foot of the table that says where the data comes from. Each call adds one.
///
/// ```gleam
/// table |> tabelline.source_note(Plain("NASA, Planetary Fact Sheet"))
/// ```
///
pub fn source_note(table: Table(row), note: Text) -> Table(row) {
  add(table, "tabSourceNote", json.object([#("note", text(note))]))
}

/// A footnote: a mark on each of these parts of the table, and the note at its foot.
///
/// ```gleam
/// table
/// |> tabelline.footnote(
///   Plain("Moons confirmed by 2025."),
///   at: [location.column_labels(["moons"])],
/// )
/// ```
///
pub fn footnote(
  table: Table(row),
  note: Text,
  at locations: List(Location),
) -> Table(row) {
  add(
    table,
    "tabFootnote",
    json.object([
      #("note", text(note)),
      #("locations", json.array(locations, of: location.to_json)),
    ]),
  )
}

// --- COLUMNS ------------------------------------------------------------------

/// The labels shown for these columns, instead of their names.
///
/// ```gleam
/// table
/// |> tabelline.labels([
///   #("diameter", Plain("Diameter (km)")),
///   #("mass", Html("Mass (10<sup>24</sup> kg)")),
/// ])
/// ```
///
pub fn labels(table: Table(row), labels: List(#(String, Text))) -> Table(row) {
  let labels = json.map(labels, fn(label) { #(label.0, text(label.1)) })
  add(table, "colsLabel", json.object([#("labels", json.object(labels))]))
}

/// A spanner: a label over these columns, which are moved next to each other.
///
/// ```gleam
/// table |> tabelline.spanner(Plain("Size"), over: ["diameter", "mass"])
/// ```
///
pub fn spanner(
  table: Table(row),
  label: Text,
  over columns: List(String),
) -> Table(row) {
  add(
    table,
    "tabSpanner",
    json.object([#("label", text(label)), #("columns", names(columns))]),
  )
}

/// These columns are not shown. A hidden column can still be read by a style or a format.
///
pub fn hide(table: Table(row), columns: List(String)) -> Table(row) {
  add(table, "colsHide", json.object([#("columns", names(columns))]))
}

// --- VALUES -------------------------------------------------------------------

/// The values of these columns written with a format.
///
/// ```gleam
/// table
/// |> tabelline.format(["diameter"], with: format.integer())
/// |> tabelline.format(["mass", "distance"], with: format.number(decimals: 1))
/// ```
///
pub fn format(
  table: Table(row),
  columns: List(String),
  with format: Format,
) -> Table(row) {
  let #(name, arguments) =
    format.to_verb(format, names(columns), rows.to_json(rows.all()))
  add(table, name, arguments)
}

/// Missing values in these columns written as `text` (by default they show as a dash).
///
/// ```gleam
/// table |> tabelline.missing(["rings"], show: "none")
/// ```
///
pub fn missing(
  table: Table(row),
  columns: List(String),
  show text: String,
) -> Table(row) {
  add(
    table,
    "subMissing",
    json.object([
      #("columns", names(columns)),
      #("missingText", json.string(text)),
    ]),
  )
}

/// The cells of these columns coloured by their value, along a palette: the lowest value
/// gets the palette's first colour, the highest its last.
///
/// ```gleam
/// table |> tabelline.colour_scale(["moons"], with: Blues)
/// ```
///
pub fn colour_scale(
  table: Table(row),
  columns: List(String),
  with palette: Palette,
) -> Table(row) {
  add(
    table,
    "dataColor",
    json.object([
      #("columns", names(columns)),
      #("palette", palette_json(palette)),
    ]),
  )
}

// --- STYLES -------------------------------------------------------------------

/// Styles for these parts of the table.
///
/// ```gleam
/// table
/// |> tabelline.style([style.bold()], at: [
///   location.body(columns: ["moons"], rows: rows.where_int("moons", Greater, 50)),
/// ])
/// ```
///
pub fn style(
  table: Table(row),
  styles: List(Style),
  at locations: List(Location),
) -> Table(row) {
  add(
    table,
    "tabStyle",
    json.object([
      #("style", json.array(styles, of: style.to_json)),
      #("locations", json.array(locations, of: location.to_json)),
    ]),
  )
}

// --- SUMMARIES ----------------------------------------------------------------

/// Summary rows at the end of each row group, one for each label: `#("Total", Sum)`.
///
/// ```gleam
/// table |> tabelline.summary_rows([#("Total", Sum), #("Mean", Mean)], of: ["moons"])
/// ```
///
pub fn summary_rows(
  table: Table(row),
  rows: List(#(String, Aggregate)),
  of columns: List(String),
) -> Table(row) {
  add(
    table,
    "summaryRows",
    json.object([#("fns", aggregates(rows)), #("columns", names(columns))]),
  )
}

/// Summary rows at the end of the table, over all its rows.
///
/// ```gleam
/// table |> tabelline.grand_summary_rows([#("Total", Sum)], of: ["moons"])
/// ```
///
pub fn grand_summary_rows(
  table: Table(row),
  rows: List(#(String, Aggregate)),
  of columns: List(String),
) -> Table(row) {
  add(
    table,
    "grandSummaryRows",
    json.object([#("fns", aggregates(rows)), #("columns", names(columns))]),
  )
}

// --- ANY VERB -----------------------------------------------------------------

/// Any of tabelline's verbs, by its name (`"fmtDate"` or `"fmt_date"`), with its arguments
/// written as a JSON object, for what this module has no function for yet:
///
/// ```gleam
/// table |> tabelline.verb("fmt_date", "{\"columns\": \"day\", \"dateStyle\": \"iso\"}")
/// ```
///
/// Arguments that are not valid JSON make the table fail to draw, with a `Rejected` error.
///
pub fn verb(table: Table(row), name: String, arguments: String) -> Table(row) {
  add(table, name, json.preprocessed(arguments))
}

fn add(table: Table(row), name: String, arguments: Json) -> Table(row) {
  Table(..table, verbs: [#(name, arguments), ..table.verbs])
}

// --- DRAWING ------------------------------------------------------------------

/// The table as HTML, with its own styles: to put in a page.
///
pub fn to_html(table: Table(row)) -> Result(String, Error) {
  render(table, "html")
}

/// The table as a whole HTML page.
///
pub fn to_page(table: Table(row)) -> Result(String, Error) {
  render(table, "page")
}

/// The table as text, drawn with box characters: for a terminal.
///
pub fn to_text(table: Table(row)) -> Result(String, Error) {
  render(table, "text")
}

/// The table in Markdown, for a README.
///
pub fn to_markdown(table: Table(row)) -> Result(String, Error) {
  render(table, "markdown")
}

/// The table as the JSON tabelline reads: its data, its settings and its steps.
///
pub fn to_json(table: Table(row)) -> String {
  json.to_string(spec(table))
}

/// A sentence that says what went wrong.
///
pub fn describe_error(error: Error) -> String {
  case error {
    DuplicateColumn(name:) ->
      "the table has two columns named \""
      <> name
      <> "\": give them different names"
    Rejected(reason:) -> "tabelline could not draw the table: " <> reason
  }
}

fn render(table: Table(row), format: String) -> Result(String, Error) {
  case duplicate(json.reverse(table.columns)) {
    Ok(name) -> Error(DuplicateColumn(name:))
    Error(Nil) ->
      case render_spec(to_json(table), format) {
        Ok(output) -> Ok(output)
        Error(reason) -> Error(Rejected(reason:))
      }
  }
}

@external(erlang, "tabelline_ffi", "render")
fn render_spec(spec: String, format: String) -> Result(String, String)

// --- HELPERS ------------------------------------------------------------------

fn spec(table: Table(row)) -> Json {
  let columns =
    json.map(json.reverse(table.columns), fn(column) {
      #(column.0, json.array(table.rows, of: column.1))
    })
  let verbs = case table.header {
    NoHeader -> json.reverse(table.verbs)
    Header(title:, subtitle:) -> {
      let arguments = case subtitle {
        Ok(subtitle) -> [#("title", title), #("subtitle", subtitle)]
        Error(Nil) -> [#("title", title)]
      }
      [#("tabHeader", json.object(arguments)), ..json.reverse(table.verbs)]
    }
  }
  json.object([
    #("data", json.object([#("columns", json.object(columns))])),
    #("verbs", json.array(verbs, of: fn(verb) { json.object([verb]) })),
    ..json.reverse(table.settings)
  ])
}

fn setting(table: Table(row), key: String, value: Json) -> Table(row) {
  Table(..table, settings: [#(key, value), ..table.settings])
}

fn text(text: Text) -> Json {
  case text {
    Plain(text) -> json.string(text)
    Markdown(text) -> json.object([#("md", json.string(text))])
    Html(text) -> json.object([#("html", json.string(text))])
  }
}

fn names(columns: List(String)) -> Json {
  json.array(columns, of: json.string)
}

fn palette_json(palette: Palette) -> Json {
  case palette {
    Blues -> json.string("blues")
    Greens -> json.string("greens")
    Reds -> json.string("reds")
    Viridis -> json.string("viridis")
    RedBlue -> json.string("rdbu")
    RedYellowGreen -> json.string("rdylgn")
    Colours(colours) -> names(colours)
  }
}

fn aggregates(rows: List(#(String, Aggregate))) -> Json {
  json.object(json.map(rows, fn(row) { #(row.0, aggregate(row.1)) }))
}

fn aggregate(aggregate: Aggregate) -> Json {
  json.string(case aggregate {
    Sum -> "sum"
    Mean -> "mean"
    Median -> "median"
    Min -> "min"
    Max -> "max"
    Count -> "count"
    StandardDeviation -> "sd"
  })
}

/// The first name that appears twice, if any.
///
fn duplicate(columns: List(#(String, a))) -> Result(String, Nil) {
  case columns {
    [] -> Error(Nil)
    [#(name, _), ..rest] ->
      case has_name(rest, name) {
        True -> Ok(name)
        False -> duplicate(rest)
      }
  }
}

fn has_name(columns: List(#(String, a)), name: String) -> Bool {
  case columns {
    [] -> False
    [#(other, _), ..rest] -> other == name || has_name(rest, name)
  }
}
