//// tabelline in the browser: a Lustre app. Every change to a control is a message, `update`
//// makes a new model, and `view` builds the table again with tabelline, compiled from Nim to
//// JavaScript, in the same page. Nothing goes to a server.

import gleam/float
import gleam/int
import gleam/list
import lustre
import lustre/attribute.{attribute, class}
import lustre/element.{type Element, text}
import lustre/element/html
import lustre/event
import tabelline.{
  type Format, AsHtml, AsMarkdown, AsText, Body, Bold, ColumnLabels, Markdown,
  Where,
}
import tabelline/json

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

// MODEL -------------------------------------------------------------------------------------

pub type Model {
  Model(
    title: String,
    locale: String,
    decimals: Int,
    palette: String,
    many_moons: Int,
    format: Format,
  )
}

fn init(_: Nil) -> Model {
  Model(
    title: "The planets",
    locale: "en",
    decimals: 2,
    palette: "blues",
    many_moons: 50,
    format: AsHtml,
  )
}

// UPDATE ------------------------------------------------------------------------------------

pub type Msg {
  UserTypedTitle(String)
  UserPickedLocale(String)
  UserMovedDecimals(String)
  UserPickedPalette(String)
  UserMovedMoons(String)
  UserPickedFormat(Format)
}

fn update(model: Model, msg: Msg) -> Model {
  case msg {
    UserTypedTitle(title) -> Model(..model, title:)
    UserPickedLocale(locale) -> Model(..model, locale:)
    UserMovedDecimals(n) ->
      Model(..model, decimals: parse_int(n, model.decimals))
    UserPickedPalette(palette) -> Model(..model, palette:)
    UserMovedMoons(n) ->
      Model(..model, many_moons: parse_int(n, model.many_moons))
    UserPickedFormat(format) -> Model(..model, format:)
  }
}

fn parse_int(s: String, default: Int) -> Int {
  case int.parse(s) {
    Ok(n) -> n
    Error(_) -> default
  }
}

// THE TABLE ---------------------------------------------------------------------------------

/// The planets table of tabelline-polyglot, with the model's choices in it.
fn planets(model: Model) -> tabelline.Table {
  tabelline.new()
  |> tabelline.strings("planet", [
    "Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn", "Uranus",
    "Neptune",
  ])
  |> tabelline.strings("type", [
    "Terrestrial", "Terrestrial", "Terrestrial", "Terrestrial", "Gas giant",
    "Gas giant", "Ice giant", "Ice giant",
  ])
  |> tabelline.ints("diameter", [
    4879, 12_104, 12_756, 6792, 142_984, 120_536, 51_118, 49_528,
  ])
  |> tabelline.floats("mass", [
    0.33, 4.87, 5.97, 0.642, 1898.0, 568.0, 86.8, 102.0,
  ])
  |> tabelline.floats("distance", [
    57.9, 108.2, 149.6, 228.0, 778.5, 1432.0, 2867.0, 4515.0,
  ])
  |> tabelline.ints("moons", [0, 0, 1, 2, 95, 146, 28, 16])
  |> tabelline.rowname("planet")
  |> tabelline.groupname("type")
  |> tabelline.id("planets")
  |> tabelline.locale(model.locale)
  |> tabelline.header(model.title, Markdown("of the *Solar System*"))
  |> tabelline.spanner("Size", ["diameter", "mass"])
  |> tabelline.labels([
    #("diameter", "Diameter (km)"),
    #("mass", "Mass (10²⁴ kg)"),
    #("distance", "From the Sun (10⁶ km)"),
    #("moons", "Moons"),
  ])
  |> tabelline.fmt_integer(columns: ["diameter"])
  |> tabelline.fmt_number(columns: ["mass"], decimals: model.decimals)
  |> tabelline.fmt_number(columns: ["distance"], decimals: 1)
  |> tabelline.data_color(columns: ["moons"], palette: model.palette)
  |> tabelline.style_cells([Bold], at: [
    Body(["moons"], Where("moons", ">", json.int(model.many_moons))),
  ])
  |> tabelline.footnote("Moons confirmed by 2025.", at: [
    ColumnLabels(["moons"]),
  ])
  |> tabelline.source_note("NASA, Planetary Fact Sheet")
}

@external(javascript, "./tabelline_ffi.mjs", "now")
fn now() -> Float

// VIEW --------------------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  let started = now()
  let rendered = tabelline.render(planets(model), model.format)
  let took = now() -. started

  html.main([class("page")], [
    html.header([class("intro")], [
      html.h1([], [text("tabelline, in your browser")]),
      html.p([class("lede")], [
        text(
          "A Lustre app written in Gleam. Each change below is a message; the table is then built again by tabelline, compiled from Nim to JavaScript, right here in the page.",
        ),
      ]),
    ]),
    controls(model),
    html.p([class("took")], [
      text(
        "tabelline took "
        <> float.to_string(float.to_precision(took, 1))
        <> " ms",
      ),
    ]),
    case rendered {
      Ok(out) ->
        case model.format {
          AsHtml -> element.unsafe_raw_html("", "div", [class("output")], out)
          _ -> html.pre([class("output text")], [text(out)])
        }
      Error(why) -> html.p([class("error")], [text(why)])
    },
  ])
}

fn controls(model: Model) -> Element(Msg) {
  html.form([class("controls"), attribute("onsubmit", "return false")], [
    field("Title", [
      html.input([
        attribute.id("title"),
        attribute.value(model.title),
        event.on_input(UserTypedTitle),
      ]),
    ]),
    field("Locale", [
      choose(
        "locale",
        model.locale,
        [
          #("en", "English"),
          #("it", "Italiano"),
          #("de", "Deutsch"),
          #("fr", "Français"),
          #("hi", "हिन्दी"),
          #("ar-EG", "العربية"),
        ],
        UserPickedLocale,
      ),
    ]),
    field("Mass decimals: " <> int.to_string(model.decimals), [
      slider("decimals", model.decimals, 0, 4, UserMovedDecimals),
    ]),
    field("Bold when moons > " <> int.to_string(model.many_moons), [
      slider("moons", model.many_moons, 0, 150, UserMovedMoons),
    ]),
    field("Palette", [
      choose(
        "palette",
        model.palette,
        list.map(["blues", "viridis", "reds", "greens", "matite"], fn(p) {
          #(p, p)
        }),
        UserPickedPalette,
      ),
    ]),
    field("Output", [
      html.div([class("formats")], [
        format_button(model, AsHtml, "HTML"),
        format_button(model, AsText, "Text"),
        format_button(model, AsMarkdown, "Markdown"),
      ]),
    ]),
  ])
}

fn field(label: String, inner: List(Element(Msg))) -> Element(Msg) {
  html.label([class("field")], [html.span([], [text(label)]), ..inner])
}

fn choose(
  id: String,
  current: String,
  options: List(#(String, String)),
  on_change: fn(String) -> Msg,
) -> Element(Msg) {
  html.select(
    [attribute.id(id), event.on_change(on_change)],
    list.map(options, fn(o) {
      html.option(
        [attribute.value(o.0), attribute.selected(o.0 == current)],
        o.1,
      )
    }),
  )
}

fn slider(
  id: String,
  value: Int,
  min: Int,
  max: Int,
  on_input: fn(String) -> Msg,
) -> Element(Msg) {
  html.input([
    attribute.id(id),
    attribute.type_("range"),
    attribute.min(int.to_string(min)),
    attribute.max(int.to_string(max)),
    attribute.value(int.to_string(value)),
    event.on_input(on_input),
  ])
}

fn format_button(model: Model, format: Format, label: String) -> Element(Msg) {
  html.button(
    [
      attribute.type_("button"),
      class(case model.format == format {
        True -> "on"
        False -> ""
      }),
      event.on_click(UserPickedFormat(format)),
    ],
    [text(label)],
  )
}
