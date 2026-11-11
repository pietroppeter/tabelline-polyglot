//// The table value itself, shared by `tabelline` and `tabelline/column`.

import tabelline/internal/json.{type Json}

pub type Table(row) {
  Table(
    rows: List(row),
    /// The columns, the last one first: a name, and what each row holds in it.
    columns: List(#(String, fn(row) -> Json)),
    /// The settings, the last one first.
    settings: List(#(String, Json)),
    header: Header,
    /// The verbs, the last one first.
    verbs: List(#(String, Json)),
  )
}

pub type Header {
  NoHeader
  Header(title: Json, subtitle: Result(Json, Nil))
}

pub fn add_column(
  table: Table(row),
  name: String,
  read: fn(row) -> Json,
) -> Table(row) {
  Table(..table, columns: [#(name, read), ..table.columns])
}
