Code.require_file("tabelline.ex", __DIR__)

Tabelline.new(
  planet: ["Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"],
  type: ["Terrestrial", "Terrestrial", "Terrestrial", "Terrestrial", "Gas giant", "Gas giant", "Ice giant", "Ice giant"],
  diameter: [4879, 12104, 12756, 6792, 142984, 120536, 51118, 49528],
  mass: [0.33, 4.87, 5.97, 0.642, 1898.0, 568.0, 86.8, 102.0],
  distance: [57.9, 108.2, 149.6, 228.0, 778.5, 1432.0, 2867.0, 4515.0],
  moons: [0, 0, 1, 2, 95, 146, 28, 16]
)
|> Tabelline.set(rownameCol: "planet", groupnameCol: "type", id: "planets")
|> Tabelline.verb(:tab_header, ["The planets", Tabelline.md("of the *Solar System*")])
|> Tabelline.verb(:tab_spanner, label: "Size", columns: ["diameter", "mass"])
|> Tabelline.verb(:cols_label,
  labels: [
    diameter: "Diameter (km)",
    mass: "Mass (10²⁴ kg)",
    distance: "From the Sun (10⁶ km)",
    moons: "Moons"
  ]
)
|> Tabelline.verb(:fmt_integer, columns: "diameter")
|> Tabelline.verb(:fmt_number, columns: "mass", decimals: 2)
|> Tabelline.verb(:fmt_number, columns: "distance", decimals: 1)
|> Tabelline.verb(:data_color, columns: "moons", palette: "blues")
|> Tabelline.verb(:tab_style,
  style: [text: [weight: "bold"]],
  locations: [[body: [columns: "moons", rows: [where: ["moons", ">", 50]]]]]
)
|> Tabelline.verb(:tab_footnote, note: "Moons confirmed by 2025.", locations: [[column_labels: "moons"]])
|> Tabelline.verb(:tab_source_note, ["NASA, Planetary Fact Sheet"])
|> Tabelline.render!(:html)
|> IO.binwrite()
