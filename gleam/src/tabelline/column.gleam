//// The columns of a table, read from your own records.
////
//// A table starts from a list of values of any type, the rows. Each column is a name, and a
//// function that reads that column's value from a row:
////
//// ```gleam
//// pub type Planet {
////   Planet(name: String, diameter: Int, mass: Float)
//// }
////
//// [Planet("Mercury", 4879, 0.33), Planet("Venus", 12_104, 4.87)]
//// |> tabelline.from_list
//// |> column.string("planet", fn(planet) { planet.name })
//// |> column.int("diameter", fn(planet) { planet.diameter })
//// |> column.float("mass", fn(planet) { planet.mass })
//// ```
////
//// Columns are shown in the order they are added. Since every column reads the same rows, all
//// columns have the same length: a table with a column that is too short cannot be written.
////

import tabelline/internal/json
import tabelline/internal/table.{type Table, add_column}

/// A column of text.
///
/// ```gleam
/// table |> column.string("planet", fn(planet) { planet.name })
/// ```
///
pub fn string(
  table: Table(row),
  name: String,
  read: fn(row) -> String,
) -> Table(row) {
  add_column(table, name, fn(row) { json.string(read(row)) })
}

/// A column of whole numbers.
///
/// ```gleam
/// table |> column.int("moons", fn(planet) { planet.moons })
/// ```
///
pub fn int(
  table: Table(row),
  name: String,
  read: fn(row) -> Int,
) -> Table(row) {
  add_column(table, name, fn(row) { json.int(read(row)) })
}

/// A column of numbers with decimals.
///
/// ```gleam
/// table |> column.float("mass", fn(planet) { planet.mass })
/// ```
///
pub fn float(
  table: Table(row),
  name: String,
  read: fn(row) -> Float,
) -> Table(row) {
  add_column(table, name, fn(row) { json.float(read(row)) })
}

/// A column of `True` and `False`.
///
/// ```gleam
/// table |> column.bool("has_rings", fn(planet) { planet.has_rings })
/// ```
///
pub fn bool(
  table: Table(row),
  name: String,
  read: fn(row) -> Bool,
) -> Table(row) {
  add_column(table, name, fn(row) { json.bool(read(row)) })
}

/// A column of numbers where some rows have no value: `Error(Nil)` is a missing value, shown
/// as a dash (`tabelline.missing` writes something else instead).
///
/// ```gleam
/// table |> column.float_or_missing("rings_mass", fn(planet) { planet.rings_mass })
/// ```
///
pub fn float_or_missing(
  table: Table(row),
  name: String,
  read: fn(row) -> Result(Float, Nil),
) -> Table(row) {
  add_column(table, name, fn(row) {
    case read(row) {
      Ok(value) -> json.float(value)
      Error(Nil) -> json.null()
    }
  })
}

/// A column of whole numbers where some rows have no value (`Error(Nil)`).
///
pub fn int_or_missing(
  table: Table(row),
  name: String,
  read: fn(row) -> Result(Int, Nil),
) -> Table(row) {
  add_column(table, name, fn(row) {
    case read(row) {
      Ok(value) -> json.int(value)
      Error(Nil) -> json.null()
    }
  })
}

/// A column of text where some rows have no value (`Error(Nil)`).
///
pub fn string_or_missing(
  table: Table(row),
  name: String,
  read: fn(row) -> Result(String, Nil),
) -> Table(row) {
  add_column(table, name, fn(row) {
    case read(row) {
      Ok(value) -> json.string(value)
      Error(Nil) -> json.null()
    }
  })
}
