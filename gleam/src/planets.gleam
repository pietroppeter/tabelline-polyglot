import tabelline.{AsHtml, Body, Bold, ColumnLabels, Markdown, Where}
import tabelline/json

@external(erlang, "tabelline_ffi", "print")
fn print(s: String) -> Nil

pub fn main() {
  let assert Ok(html) =
    tabelline.new()
    |> tabelline.strings("planet", [
      "Mercury",
      "Venus",
      "Earth",
      "Mars",
      "Jupiter",
      "Saturn",
      "Uranus",
      "Neptune",
    ])
    |> tabelline.strings("type", [
      "Terrestrial",
      "Terrestrial",
      "Terrestrial",
      "Terrestrial",
      "Gas giant",
      "Gas giant",
      "Ice giant",
      "Ice giant",
    ])
    |> tabelline.ints("diameter", [
      4879,
      12_104,
      12_756,
      6792,
      142_984,
      120_536,
      51_118,
      49_528,
    ])
    |> tabelline.floats("mass", [
      0.33,
      4.87,
      5.97,
      0.642,
      1898.0,
      568.0,
      86.8,
      102.0,
    ])
    |> tabelline.floats("distance", [
      57.9,
      108.2,
      149.6,
      228.0,
      778.5,
      1432.0,
      2867.0,
      4515.0,
    ])
    |> tabelline.ints("moons", [0, 0, 1, 2, 95, 146, 28, 16])
    |> tabelline.rowname("planet")
    |> tabelline.groupname("type")
    |> tabelline.id("planets")
    |> tabelline.header("The planets", Markdown("of the *Solar System*"))
    |> tabelline.spanner("Size", ["diameter", "mass"])
    |> tabelline.labels([
      #("diameter", "Diameter (km)"),
      #("mass", "Mass (10²⁴ kg)"),
      #("distance", "From the Sun (10⁶ km)"),
      #("moons", "Moons"),
    ])
    |> tabelline.fmt_integer(columns: ["diameter"])
    |> tabelline.fmt_number(columns: ["mass"], decimals: 2)
    |> tabelline.fmt_number(columns: ["distance"], decimals: 1)
    |> tabelline.data_color(columns: ["moons"], palette: "blues")
    |> tabelline.style_cells([Bold], at: [
      Body(["moons"], Where("moons", ">", json.int(50))),
    ])
    |> tabelline.footnote("Moons confirmed by 2025.", at: [
      ColumnLabels(["moons"]),
    ])
    |> tabelline.source_note("NASA, Planetary Fact Sheet")
    |> tabelline.render(AsHtml)
  print(html)
}
