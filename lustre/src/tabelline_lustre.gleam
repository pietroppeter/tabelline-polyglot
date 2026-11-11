//// tabelline's tables in a [Lustre](https://hexdocs.pm/lustre/) app: a table is an element.
////
//// ```gleam
//// import tabelline_lustre
////
//// fn view(model: Model) -> Element(Msg) {
////   html.main([], [controls(model), tabelline_lustre.view(planets(model))])
//// }
//// ```
////
//// The table is drawn when the view is: by tabelline compiled to JavaScript in a browser, by
//// its NIF on the BEAM (a server component, or HTML written on the server). A table that
//// cannot be drawn shows why, in a paragraph, instead of breaking the page.
////

import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html
import tabelline.{type Table}

/// The table, as HTML in a `div` with the class `tabelline`.
///
pub fn view(table: Table(row)) -> Element(msg) {
  view_with(table, [])
}

/// The table, as HTML in a `div` with these attributes too.
///
pub fn view_with(
  table: Table(row),
  attributes: List(Attribute(msg)),
) -> Element(msg) {
  case tabelline.to_html(table) {
    // tabelline escapes every value it writes, so its HTML can go in the page as it is
    Ok(drawn) ->
      element.unsafe_raw_html(
        "",
        "div",
        [attribute.class("tabelline"), ..attributes],
        drawn,
      )
    Error(error) -> problem(error)
  }
}

/// The table drawn as text, with box characters, in a `pre`.
///
pub fn view_text(table: Table(row)) -> Element(msg) {
  preformatted(tabelline.to_text(table))
}

/// The table in Markdown, in a `pre`.
///
pub fn view_markdown(table: Table(row)) -> Element(msg) {
  preformatted(tabelline.to_markdown(table))
}

fn preformatted(drawn: Result(String, tabelline.Error)) -> Element(msg) {
  case drawn {
    Ok(drawn) -> html.pre([attribute.class("tabelline")], [element.text(drawn)])
    Error(error) -> problem(error)
  }
}

fn problem(error: tabelline.Error) -> Element(msg) {
  html.p([attribute.class("tabelline-error"), attribute.role("alert")], [
    element.text(tabelline.describe_error(error)),
  ])
}
