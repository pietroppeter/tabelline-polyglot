//// The planets table, the one every port of tabelline draws.
////
//// `gleam run -m planets` prints it as HTML (compared with Nim's by `tools/polyglot.nim`);
//// `gleam run -m planets -- text` prints it for the terminal.
////

import tabelline.{type Table, Blues, Markdown, Plain}
import tabelline/column
import tabelline/format
import tabelline/location
import tabelline/rows.{Greater}
import tabelline/style

pub type Planet {
  Planet(
    name: String,
    kind: Kind,
    diameter: Int,
    mass: Float,
    distance: Float,
    moons: Int,
  )
}

pub type Kind {
  Terrestrial
  GasGiant
  IceGiant
}

pub fn planets() -> List(Planet) {
  [
    Planet("Mercury", Terrestrial, 4879, 0.33, 57.9, 0),
    Planet("Venus", Terrestrial, 12_104, 4.87, 108.2, 0),
    Planet("Earth", Terrestrial, 12_756, 5.97, 149.6, 1),
    Planet("Mars", Terrestrial, 6792, 0.642, 228.0, 2),
    Planet("Jupiter", GasGiant, 142_984, 1898.0, 778.5, 95),
    Planet("Saturn", GasGiant, 120_536, 568.0, 1432.0, 146),
    Planet("Uranus", IceGiant, 51_118, 86.8, 2867.0, 28),
    Planet("Neptune", IceGiant, 49_528, 102.0, 4515.0, 16),
  ]
}

pub fn table() -> Table(Planet) {
  planets()
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
  |> tabelline.title(Plain("The planets"))
  |> tabelline.subtitle(Markdown("of the *Solar System*"))
  |> tabelline.spanner(Plain("Size"), over: ["diameter", "mass"])
  |> tabelline.labels([
    #("diameter", Plain("Diameter (km)")),
    #("mass", Plain("Mass (10²⁴ kg)")),
    #("distance", Plain("From the Sun (10⁶ km)")),
    #("moons", Plain("Moons")),
  ])
  |> tabelline.format(["diameter"], with: format.integer())
  |> tabelline.format(["mass"], with: format.number(decimals: 2))
  |> tabelline.format(["distance"], with: format.number(decimals: 1))
  |> tabelline.colour_scale(["moons"], with: Blues)
  |> tabelline.style([style.bold()], at: [
    location.body(
      columns: ["moons"],
      rows: rows.where_int("moons", Greater, 50),
    ),
  ])
  |> tabelline.footnote(Plain("Moons confirmed by 2025."), at: [
    location.column_labels(["moons"]),
  ])
  |> tabelline.source_note(Plain("NASA, Planetary Fact Sheet"))
}

fn kind_name(kind: Kind) -> String {
  case kind {
    Terrestrial -> "Terrestrial"
    GasGiant -> "Gas giant"
    IceGiant -> "Ice giant"
  }
}

pub fn main() {
  let drawn = case arguments() {
    ["text"] -> tabelline.to_text(table())
    ["markdown"] -> tabelline.to_markdown(table())
    _ -> tabelline.to_html(table())
  }
  case drawn {
    Ok(output) -> print(output)
    Error(error) -> print(tabelline.describe_error(error) <> "\n")
  }
}

@external(erlang, "tabelline_ffi", "print")
fn print(text: String) -> Nil

@external(erlang, "tabelline_ffi", "arguments")
fn arguments() -> List(String)
