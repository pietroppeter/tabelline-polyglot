//// The parts of a table, for a style or a footnote.
////
//// ```text
//// ┌────────────────────────────────────────┐
//// │ title                                  │ header
//// │ subtitle                               │
//// ├───────────┬────────────────────────────┤
//// │ stubhead  │ spanners                   │
//// │           │ column labels              │
//// ├───────────┼────────────────────────────┤
//// │ row group                              │
//// │ stub      │ body                       │
//// ├───────────┴────────────────────────────┤
//// │ footnotes                              │ footer
//// │ source notes                           │
//// └────────────────────────────────────────┘
//// ```
////

import tabelline/internal/json.{type Json}
import tabelline/rows.{type Rows}

/// A part of a table.
///
pub opaque type Location {
  Title
  Subtitle
  Stubhead
  ColumnLabels(columns: List(String))
  Spanners(labels: List(String))
  RowGroups(names: List(String))
  Stub(rows: Rows)
  Body(columns: List(String), rows: Rows)
  Footnotes
  SourceNotes
}

/// The title.
///
pub fn title() -> Location {
  Title
}

/// The subtitle.
///
pub fn subtitle() -> Location {
  Subtitle
}

/// The label above the stub, the column of row names.
///
pub fn stubhead() -> Location {
  Stubhead
}

/// The labels of these columns.
///
/// ```gleam
/// location.column_labels(["moons"])
/// ```
///
pub fn column_labels(columns: List(String)) -> Location {
  ColumnLabels(columns)
}

/// The spanners with these labels.
///
pub fn spanners(labels: List(String)) -> Location {
  Spanners(labels)
}

/// The labels of these row groups.
///
pub fn row_groups(names: List(String)) -> Location {
  RowGroups(names)
}

/// The names of these rows, in the stub.
///
/// ```gleam
/// location.stub(rows.at([2]))
/// ```
///
pub fn stub(rows: Rows) -> Location {
  Stub(rows)
}

/// The cells of these columns, in these rows.
///
/// ```gleam
/// location.body(columns: ["moons"], rows: rows.where_int("moons", Greater, 50))
/// ```
///
pub fn body(columns columns: List(String), rows rows: Rows) -> Location {
  Body(columns:, rows:)
}

/// The footnotes, in the footer.
///
pub fn footnotes() -> Location {
  Footnotes
}

/// The source notes, in the footer.
///
pub fn source_notes() -> Location {
  SourceNotes
}

@internal
pub fn to_json(location: Location) -> Json {
  let names = fn(names) { json.array(names, of: json.string) }
  case location {
    Title -> json.string("title")
    Subtitle -> json.string("subtitle")
    Stubhead -> json.string("stubhead")
    Footnotes -> json.string("footnotes")
    SourceNotes -> json.string("sourceNotes")
    ColumnLabels(columns) -> json.object([#("columnLabels", names(columns))])
    Spanners(labels) -> json.object([#("spanners", names(labels))])
    RowGroups(groups) -> json.object([#("rowGroups", names(groups))])
    Stub(rows) ->
      json.object([#("stub", json.object([#("rows", rows.to_json(rows))]))])
    Body(columns:, rows:) ->
      json.object([
        #(
          "body",
          json.object([
            #("columns", names(columns)),
            #("rows", rows.to_json(rows)),
          ]),
        ),
      ])
  }
}
