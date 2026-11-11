//// Which rows of the body a style, a format or a footnote is for.
////
//// ```gleam
//// rows.all()
//// rows.at([0, 2])
//// rows.where_int("moons", Greater, 50)
//// rows.where_string("type", Equal, "Gas giant")
//// ```
////
//// Rows are counted from 0, in the order of the list the table was built from.
////

import tabelline/internal/json.{type Json}

/// A choice of rows.
///
pub opaque type Rows {
  All
  At(indices: List(Int))
  Where(column: String, comparison: Comparison, value: Json)
}

/// How a row's value is compared with the one you give.
///
pub type Comparison {
  Equal
  NotEqual
  Less
  LessOrEqual
  Greater
  GreaterOrEqual
}

/// Every row.
///
pub fn all() -> Rows {
  All
}

/// The rows at these positions, counted from 0.
///
/// ```gleam
/// rows.at([0, 2]) // the first and the third row
/// ```
///
pub fn at(indices: List(Int)) -> Rows {
  At(indices)
}

/// The rows whose value in `column`, a column of whole numbers, compares to `value`.
///
/// ```gleam
/// rows.where_int("moons", Greater, 50) // the planets with more than 50 moons
/// ```
///
pub fn where_int(column: String, comparison: Comparison, value: Int) -> Rows {
  Where(column:, comparison:, value: json.int(value))
}

/// The rows whose value in `column`, a column of numbers, compares to `value`.
///
/// ```gleam
/// rows.where_float("mass", Less, 1.0)
/// ```
///
pub fn where_float(
  column: String,
  comparison: Comparison,
  value: Float,
) -> Rows {
  Where(column:, comparison:, value: json.float(value))
}

/// The rows whose value in `column`, a column of text, compares to `value` (in alphabetical
/// order for `Less` and `Greater`).
///
/// ```gleam
/// rows.where_string("type", Equal, "Gas giant")
/// ```
///
pub fn where_string(
  column: String,
  comparison: Comparison,
  value: String,
) -> Rows {
  Where(column:, comparison:, value: json.string(value))
}

/// The rows whose value in `column`, a column of `True` and `False`, is `value`.
///
/// ```gleam
/// rows.where_bool("has_rings", True)
/// ```
///
pub fn where_bool(column: String, value: Bool) -> Rows {
  Where(column:, comparison: Equal, value: json.bool(value))
}

@internal
pub fn to_json(rows: Rows) -> Json {
  case rows {
    All -> json.object([#("all", json.bool(True))])
    At(indices) -> json.array(indices, of: json.int)
    Where(column:, comparison:, value:) ->
      json.object([
        #(
          "where",
          json.preprocessed_array([
            json.string(column),
            json.string(operator(comparison)),
            value,
          ]),
        ),
      ])
  }
}

fn operator(comparison: Comparison) -> String {
  case comparison {
    Equal -> "=="
    NotEqual -> "!="
    Less -> "<"
    LessOrEqual -> "<="
    Greater -> ">"
    GreaterOrEqual -> ">="
  }
}
