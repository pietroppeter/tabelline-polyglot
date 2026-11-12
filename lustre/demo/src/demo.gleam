//// tabelline in the browser: a Lustre app. Every change to a control is a message, `update`
//// makes a new model, and `view` builds the tables again with tabelline, compiled from Nim to
//// JavaScript, in the same page. Nothing goes to a server.

import gleam/float
import gleam/int
import gleam/list
import lustre
import lustre/attribute.{class}
import lustre/element.{type Element, text}
import lustre/element/html
import lustre/event
import planets.{type Planet, GasGiant, IceGiant, Terrestrial}
import tabelline.{
  type Dataset, type Palette, type Table, Blues, Citta, Countrypops, Exibble,
  Greens, Gtcars, Illness, Isole, Markdown, Metro, Plain, RedYellowGreen, Reds,
  Viridis,
}
import tabelline/column
import tabelline/format
import tabelline/location
import tabelline/rows.{Greater}
import tabelline/style
import tabelline_lustre

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

// MODEL ---------------------------------------------------------------------------------

pub type Model {
  Model(
    title: String,
    locale: String,
    decimals: Int,
    palette: Palette,
    many_moons: Int,
    output: Output,
    dataset: Dataset,
    top: Int,
    bottom: Int,
  )
}

pub type Output {
  AsHtml
  AsText
  AsMarkdown
}

fn init(_: Nil) -> Model {
  Model(
    title: "The planets",
    locale: "en",
    decimals: 2,
    palette: Blues,
    many_moons: 50,
    output: AsHtml,
    dataset: Gtcars,
    top: 5,
    bottom: 1,
  )
}

// UPDATE --------------------------------------------------------------------------------

pub type Msg {
  UserTypedTitle(String)
  UserPickedLocale(String)
  UserMovedDecimals(Int)
  UserPickedPalette(Palette)
  UserMovedMoons(Int)
  UserPickedOutput(Output)
  UserPickedDataset(Dataset)
  UserMovedTop(Int)
  UserMovedBottom(Int)
}

fn update(model: Model, msg: Msg) -> Model {
  case msg {
    UserTypedTitle(title) -> Model(..model, title:)
    UserPickedLocale(locale) -> Model(..model, locale:)
    UserMovedDecimals(decimals) -> Model(..model, decimals:)
    UserPickedPalette(palette) -> Model(..model, palette:)
    UserMovedMoons(many_moons) -> Model(..model, many_moons:)
    UserPickedOutput(output) -> Model(..model, output:)
    UserPickedDataset(dataset) -> Model(..model, dataset:)
    UserMovedTop(top) -> Model(..model, top:)
    UserMovedBottom(bottom) -> Model(..model, bottom:)
  }
}

// THE TABLES ----------------------------------------------------------------------------

/// The planets table of tabelline-polyglot, with the model's choices in it.
fn planets_table(model: Model) -> Table(Planet) {
  planets.planets()
  |> tabelline.from_list
  |> column.string("planet", fn(planet) { planet.name })
  |> column.string("type", fn(planet) { kind_name(planet.kind) })
  |> column.int("diameter", fn(planet) { planet.diameter })
  |> column.float("mass", fn(planet) { planet.mass })
  |> column.float("distance", fn(planet) { planet.distance })
  |> column.int("moons", fn(planet) { planet.moons })
  |> tabelline.stub("planet")
  |> tabelline.group_by("type")
  |> tabelline.id("planets")
  |> tabelline.locale(model.locale)
  |> tabelline.title(Plain(model.title))
  |> tabelline.subtitle(Markdown("of the *Solar System*"))
  |> tabelline.spanner(Plain("Size"), over: ["diameter", "mass"])
  |> tabelline.labels([
    #("diameter", Plain("Diameter (km)")),
    #("mass", Plain("Mass (10²⁴ kg)")),
    #("distance", Plain("From the Sun (10⁶ km)")),
    #("moons", Plain("Moons")),
  ])
  |> tabelline.format(["diameter"], with: format.integer())
  |> tabelline.format(["mass"], with: format.number(decimals: model.decimals))
  |> tabelline.format(["distance"], with: format.number(decimals: 1))
  |> tabelline.colour_scale(["moons"], with: model.palette)
  |> tabelline.style([style.bold()], at: [
    location.body(
      columns: ["moons"],
      rows: rows.where_int("moons", Greater, model.many_moons),
    ),
  ])
  |> tabelline.footnote(Plain("Moons confirmed by 2025."), at: [
    location.column_labels(["moons"]),
  ])
  |> tabelline.source_note(Plain("NASA, Planetary Fact Sheet"))
}

fn kind_name(kind: planets.Kind) -> String {
  case kind {
    Terrestrial -> "Terrestrial"
    GasGiant -> "Gas giant"
    IceGiant -> "Ice giant"
  }
}

/// A look at one of tabelline's datasets: its first and last rows.
fn dataset_table(model: Model) -> Table(Nil) {
  let #(_, name, about) = dataset_info(model.dataset)
  tabelline.from_dataset(model.dataset)
  |> tabelline.preview(top: model.top, bottom: model.bottom)
  |> tabelline.id("dataset")
  |> tabelline.locale(model.locale)
  |> tabelline.title(Plain(name))
  |> tabelline.subtitle(Plain(about))
}

const datasets = [
  #(Gtcars, "gtcars", "47 deluxe cars of the 2014-2017 model years"),
  #(Countrypops, "countrypops", "every country's population, 1960 to 2022"),
  #(Metro, "metro", "the stations of the Paris Metro"),
  #(Illness, "illness", "daily tests of a patient with yellow fever"),
  #(Isole, "isole", "the 194 islands of the Mediterranean"),
  #(Citta, "citta", "the 95 largest cities of the European Union"),
  #(Exibble, "exibble", "gt's tiny example table, a column of each type"),
]

fn dataset_info(dataset: Dataset) -> #(Dataset, String, String) {
  case list.find(datasets, fn(d) { d.0 == dataset }) {
    Ok(info) -> info
    Error(Nil) -> #(dataset, "?", "")
  }
}

// VIEW ----------------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  let #(planets, planets_took) =
    timed(fn() { draw(planets_table(model), model) })
  let #(dataset, dataset_took) =
    timed(fn() { draw(dataset_table(model), model) })
  html.main([class("page")], [
    html.header([class("intro")], [
      html.h1([], [text("tabelline, in your browser")]),
      html.p([class("lede")], [
        text(
          "A Lustre app written in Gleam. Each change below is a message; the tables are then built again by tabelline, compiled from Nim to JavaScript, right here in the page.",
        ),
      ]),
    ]),
    html.section([], [
      html.h2([], [text("The planets")]),
      planet_controls(model),
      took(planets_took),
      planets,
    ]),
    html.section([], [
      html.h2([], [text("A dataset")]),
      dataset_controls(model),
      took(dataset_took),
      dataset,
    ]),
  ])
}

fn draw(table: Table(row), model: Model) -> Element(Msg) {
  case model.output {
    AsHtml -> tabelline_lustre.view_with(table, [class("output")])
    AsText -> tabelline_lustre.view_text(table)
    AsMarkdown -> tabelline_lustre.view_markdown(table)
  }
}

fn timed(f: fn() -> a) -> #(a, Float) {
  let started = now()
  let result = f()
  #(result, now() -. started)
}

@external(javascript, "./demo_ffi.mjs", "now")
fn now() -> Float

fn took(ms: Float) -> Element(Msg) {
  html.p([class("took")], [
    text(
      "tabelline took " <> float.to_string(float.to_precision(ms, 1)) <> " ms",
    ),
  ])
}

fn planet_controls(model: Model) -> Element(Msg) {
  html.div([class("controls")], [
    field("Title", [
      html.input([
        attribute.value(model.title),
        event.on_input(UserTypedTitle),
      ]),
    ]),
    field("Locale", [
      choose(
        model.locale,
        [
          #("en", "English"),
          #("it", "Italiano"),
          #("de", "Deutsch"),
          #("fr", "Français"),
          #("hi", "हिन्दी"),
          #("ar-EG", "العربية"),
        ],
        fn(locale) { locale },
        UserPickedLocale,
      ),
    ]),
    field("Mass decimals: " <> int.to_string(model.decimals), [
      slider(model.decimals, 0, 4, UserMovedDecimals),
    ]),
    field("Bold when moons > " <> int.to_string(model.many_moons), [
      slider(model.many_moons, 0, 150, UserMovedMoons),
    ]),
    field("Palette", [
      choose(
        model.palette,
        [
          #(Blues, "blues"),
          #(Viridis, "viridis"),
          #(Reds, "reds"),
          #(Greens, "greens"),
          #(RedYellowGreen, "red, yellow, green"),
        ],
        palette_key,
        UserPickedPalette,
      ),
    ]),
    field("Output", [
      html.div([class("formats")], [
        output_button(model, AsHtml, "HTML"),
        output_button(model, AsText, "Text"),
        output_button(model, AsMarkdown, "Markdown"),
      ]),
    ]),
  ])
}

fn dataset_controls(model: Model) -> Element(Msg) {
  html.div([class("controls")], [
    field("Dataset", [
      choose(
        model.dataset,
        list.map(datasets, fn(d) { #(d.0, d.1) }),
        fn(dataset) { dataset_info(dataset).1 },
        UserPickedDataset,
      ),
    ]),
    field("First rows: " <> int.to_string(model.top), [
      slider(model.top, 1, 20, UserMovedTop),
    ]),
    field("Last rows: " <> int.to_string(model.bottom), [
      slider(model.bottom, 0, 10, UserMovedBottom),
    ]),
  ])
}

fn palette_key(palette: Palette) -> String {
  case palette {
    Blues -> "blues"
    Viridis -> "viridis"
    Reds -> "reds"
    Greens -> "greens"
    _ -> "rdylgn"
  }
}

fn field(label: String, inner: List(Element(Msg))) -> Element(Msg) {
  html.label([class("field")], [html.span([], [text(label)]), ..inner])
}

/// A drop-down of typed choices: each option's value is `key(choice)`.
fn choose(
  current: a,
  options: List(#(a, String)),
  key: fn(a) -> String,
  on_change: fn(a) -> Msg,
) -> Element(Msg) {
  let pick = fn(value) {
    case list.find(options, fn(o) { key(o.0) == value }) {
      Ok(o) -> on_change(o.0)
      Error(Nil) -> on_change(current)
    }
  }
  html.select(
    [event.on_change(pick)],
    list.map(options, fn(o) {
      html.option(
        [attribute.value(key(o.0)), attribute.selected(o.0 == current)],
        o.1,
      )
    }),
  )
}

fn slider(
  value: Int,
  min: Int,
  max: Int,
  on_input: fn(Int) -> Msg,
) -> Element(Msg) {
  html.input([
    attribute.type_("range"),
    attribute.min(int.to_string(min)),
    attribute.max(int.to_string(max)),
    attribute.value(int.to_string(value)),
    event.on_input(fn(s) {
      case int.parse(s) {
        Ok(n) -> on_input(n)
        Error(Nil) -> on_input(value)
      }
    }),
  ])
}

fn output_button(model: Model, output: Output, label: String) -> Element(Msg) {
  html.button(
    [
      attribute.type_("button"),
      class(case model.output == output {
        True -> "on"
        False -> ""
      }),
      event.on_click(UserPickedOutput(output)),
    ],
    [text(label)],
  )
}
