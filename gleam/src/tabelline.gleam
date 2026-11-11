//// Great tables for Gleam: tabelline (Nim) on the BEAM. A proof of concept.
////
//// A table is a plain Gleam value: columns, settings and verbs, added with `|>`. Nothing runs
//// until `render`, which writes the table as JSON and hands it to libtabelline through one NIF
//// (`tabelline_nif`), on a dirty scheduler.
////
//// ```gleam
//// tabelline.new()
//// |> tabelline.strings("planet", ["Mercury", "Venus"])
//// |> tabelline.floats("mass", [0.33, 4.87])
//// |> tabelline.rowname("planet")
//// |> tabelline.header("The planets", Markdown("of the *Solar System*"))
//// |> tabelline.fmt_number(columns: ["mass"], decimals: 2)
//// |> tabelline.render(AsHtml)
//// ```

import tabelline/json.{type Json}

pub opaque type Table {
  Table(
    columns: List(#(String, Json)),
    settings: List(#(String, Json)),
    verbs: List(Json),
  )
}

/// Text in a title, a label or a note.
pub type Text {
  Plain(String)
  Markdown(String)
  Html(String)
}

pub type Format {
  AsHtml
  AsPage
  AsText
  AsMarkdown
}

/// Which rows of the body.
pub type Rows {
  AllRows
  Indices(List(Int))
  Where(column: String, op: String, value: Json)
}

/// A part of the table, for styles and footnotes.
pub type Location {
  Title
  Subtitle
  ColumnLabels(columns: List(String))
  Body(columns: List(String), rows: Rows)
  Stub(rows: Rows)
  SourceNotes
}

pub type Style {
  Fill(colour: String)
  Bold
  Italic
  TextColour(colour: String)
  Css(declarations: String)
}

pub fn new() -> Table {
  Table([], [], [])
}

// ---------------------------------------------------------------------------------- columns

fn column(t: Table, name: String, values: Json) -> Table {
  Table(..t, columns: append(t.columns, #(name, values)))
}

pub fn strings(t: Table, name: String, values: List(String)) -> Table {
  column(t, name, json.array(values, json.string))
}

pub fn ints(t: Table, name: String, values: List(Int)) -> Table {
  column(t, name, json.array(values, json.int))
}

pub fn floats(t: Table, name: String, values: List(Float)) -> Table {
  column(t, name, json.array(values, json.float))
}

pub fn bools(t: Table, name: String, values: List(Bool)) -> Table {
  column(t, name, json.array(values, json.bool))
}

// --------------------------------------------------------------------------------- settings

fn setting(t: Table, key: String, value: String) -> Table {
  Table(..t, settings: append(t.settings, #(key, json.string(value))))
}

/// The column of row names: the stub.
pub fn rowname(t: Table, column: String) -> Table {
  setting(t, "rownameCol", column)
}

/// The column whose values group the rows.
pub fn groupname(t: Table, column: String) -> Table {
  setting(t, "groupnameCol", column)
}

pub fn id(t: Table, id: String) -> Table {
  setting(t, "id", id)
}

pub fn locale(t: Table, locale: String) -> Table {
  setting(t, "locale", locale)
}

// ------------------------------------------------------------------------------------ verbs

/// Any verb of tabelline, by name (`"fmt_number"` or `"fmtNumber"`), with its arguments:
/// a JSON array for positional ones, an object for named ones.
pub fn verb(t: Table, name: String, args: Json) -> Table {
  Table(..t, verbs: append(t.verbs, json.object([#(name, args)])))
}

fn text(t: Text) -> Json {
  case t {
    Plain(s) -> json.string(s)
    Markdown(s) -> json.object([#("md", json.string(s))])
    Html(s) -> json.object([#("html", json.string(s))])
  }
}

fn names(columns: List(String)) -> Json {
  json.array(columns, json.string)
}

fn rows(r: Rows) -> Json {
  case r {
    AllRows -> json.object([#("all", json.bool(True))])
    Indices(ix) -> json.array(ix, json.int)
    Where(column, op, value) ->
      json.object([
        #(
          "where",
          json.preprocessed_array([json.string(column), json.string(op), value]),
        ),
      ])
  }
}

fn location(l: Location) -> Json {
  case l {
    Title -> json.string("title")
    Subtitle -> json.string("subtitle")
    SourceNotes -> json.string("sourceNotes")
    ColumnLabels(columns) -> json.object([#("columnLabels", names(columns))])
    Body(columns, r) ->
      json.object([
        #(
          "body",
          json.object([#("columns", names(columns)), #("rows", rows(r))]),
        ),
      ])
    Stub(r) -> json.object([#("stub", json.object([#("rows", rows(r))]))])
  }
}

fn style(s: Style) -> Json {
  case s {
    Fill(c) -> json.object([#("fill", json.string(c))])
    Bold ->
      json.object([#("text", json.object([#("weight", json.string("bold"))]))])
    Italic ->
      json.object([#("text", json.object([#("style", json.string("italic"))]))])
    TextColour(c) ->
      json.object([#("text", json.object([#("color", json.string(c))]))])
    Css(d) -> json.object([#("css", json.string(d))])
  }
}

pub fn header(t: Table, title: String, subtitle: Text) -> Table {
  verb(
    t,
    "tabHeader",
    json.preprocessed_array([json.string(title), text(subtitle)]),
  )
}

pub fn spanner(t: Table, label: String, columns: List(String)) -> Table {
  verb(
    t,
    "tabSpanner",
    json.object([#("label", json.string(label)), #("columns", names(columns))]),
  )
}

pub fn labels(t: Table, labels: List(#(String, String))) -> Table {
  let pairs = json.map(labels, fn(p) { #(p.0, json.string(p.1)) })
  verb(t, "colsLabel", json.object([#("labels", json.object(pairs))]))
}

pub fn fmt_integer(t: Table, columns columns: List(String)) -> Table {
  verb(t, "fmtInteger", json.object([#("columns", names(columns))]))
}

pub fn fmt_number(
  t: Table,
  columns columns: List(String),
  decimals decimals: Int,
) -> Table {
  verb(
    t,
    "fmtNumber",
    json.object([
      #("columns", names(columns)),
      #("decimals", json.int(decimals)),
    ]),
  )
}

pub fn data_color(
  t: Table,
  columns columns: List(String),
  palette palette: String,
) -> Table {
  verb(
    t,
    "dataColor",
    json.object([
      #("columns", names(columns)),
      #("palette", json.string(palette)),
    ]),
  )
}

pub fn style_cells(
  t: Table,
  styles: List(Style),
  at locations: List(Location),
) -> Table {
  verb(
    t,
    "tabStyle",
    json.object([
      #("style", json.array(styles, style)),
      #("locations", json.array(locations, location)),
    ]),
  )
}

pub fn footnote(t: Table, note: String, at locations: List(Location)) -> Table {
  verb(
    t,
    "tabFootnote",
    json.object([
      #("note", json.string(note)),
      #("locations", json.array(locations, location)),
    ]),
  )
}

pub fn source_note(t: Table, note: String) -> Table {
  verb(t, "tabSourceNote", json.preprocessed_array([json.string(note)]))
}

// ----------------------------------------------------------------------------------- render

/// The table as JSON, the spec libtabelline reads.
pub fn to_spec(t: Table) -> Json {
  json.object([
    #("data", json.object([#("columns", json.object(t.columns))])),
    ..concat(t.settings, [#("verbs", json.preprocessed_array(t.verbs))])
  ])
}

@external(erlang, "tabelline_ffi", "render")
fn render_spec(spec: String, format: String) -> Result(String, String)

pub fn render(t: Table, format: Format) -> Result(String, String) {
  let f = case format {
    AsHtml -> "html"
    AsPage -> "page"
    AsText -> "text"
    AsMarkdown -> "markdown"
  }
  render_spec(json.to_string(to_spec(t)), f)
}

fn append(xs: List(a), x: a) -> List(a) {
  case xs {
    [] -> [x]
    [y, ..rest] -> [y, ..append(rest, x)]
  }
}

fn concat(xs: List(a), ys: List(a)) -> List(a) {
  case xs {
    [] -> ys
    [x, ..rest] -> [x, ..concat(rest, ys)]
  }
}
