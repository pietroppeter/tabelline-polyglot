//// How cells look: their fill, their text, their borders.
////
//// ```gleam
//// table
//// |> tabelline.style(
////   [style.bold(), style.text_colour("#08306B")],
////   at: [location.body(columns: ["moons"], rows: rows.where_int("moons", Greater, 50))],
//// )
//// ```
////
//// A colour is any CSS colour: `"#fff3b0"`, `"crimson"`, `"var(--primary)"`.
////

import tabelline/internal/json.{type Json}

/// One thing about how a cell looks.
///
pub opaque type Style {
  Fill(colour: String)
  Text(property: String, value: String)
  Border(sides: List(Side), colour: String, width: String)
  Css(declarations: String)
}

/// A side of a cell, for borders.
///
pub type Side {
  Top
  Bottom
  Left
  Right
}

/// The cell filled with a colour.
///
pub fn fill(colour: String) -> Style {
  Fill(colour)
}

/// Bold text.
///
pub fn bold() -> Style {
  Text("weight", "bold")
}

/// Italic text.
///
pub fn italic() -> Style {
  Text("style", "italic")
}

/// Text in a colour.
///
pub fn text_colour(colour: String) -> Style {
  Text("color", colour)
}

/// Text of a size: any CSS size, `"small"`, `"1.2em"`, `"14px"`.
///
pub fn text_size(size: String) -> Style {
  Text("size", size)
}

/// A border on some sides of the cell.
///
/// ```gleam
/// style.border([Top, Bottom], colour: "#000", width: "2px")
/// ```
///
pub fn border(
  sides: List(Side),
  colour colour: String,
  width width: String,
) -> Style {
  Border(sides:, colour:, width:)
}

/// Any CSS declarations, when nothing else says it: `style.css("letter-spacing: .1em")`.
///
pub fn css(declarations: String) -> Style {
  Css(declarations)
}

@internal
pub fn to_json(style: Style) -> Json {
  case style {
    Fill(colour) -> json.object([#("fill", json.string(colour))])
    Text(property, value) ->
      json.object([#("text", json.object([#(property, json.string(value))]))])
    Css(declarations) -> json.object([#("css", json.string(declarations))])
    Border(sides:, colour:, width:) ->
      json.object([
        #(
          "borders",
          json.object([
            #("sides", json.array(sides, of: side)),
            #("color", json.string(colour)),
            #("weight", json.string(width)),
          ]),
        ),
      ])
  }
}

fn side(side: Side) -> Json {
  case side {
    Top -> json.string("top")
    Bottom -> json.string("bottom")
    Left -> json.string("left")
    Right -> json.string("right")
  }
}
