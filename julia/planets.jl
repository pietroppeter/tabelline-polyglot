include(joinpath(@__DIR__, "Tabelline.jl"))
using .Tabelline

planets = (
    planet = ["Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"],
    type = ["Terrestrial", "Terrestrial", "Terrestrial", "Terrestrial", "Gas giant", "Gas giant", "Ice giant", "Ice giant"],
    diameter = [4879, 12104, 12756, 6792, 142984, 120536, 51118, 49528],
    mass = [0.33, 4.87, 5.97, 0.642, 1898.0, 568.0, 86.8, 102.0],
    distance = [57.9, 108.2, 149.6, 228.0, 778.5, 1432.0, 2867.0, 4515.0],
    moons = [0, 0, 1, 2, 95, 146, 28, 16],
)

t = tabella(planets; rownameCol = "planet", groupnameCol = "type", id = "planets") |>
    tab_header("The planets", md("of the *Solar System*")) |>
    tab_spanner("Size", ["diameter", "mass"]) |>
    cols_label(labels = (diameter = "Diameter (km)", mass = "Mass (10²⁴ kg)",
                         distance = "From the Sun (10⁶ km)", moons = "Moons")) |>
    fmt_integer("diameter") |>
    fmt_number(columns = "mass", decimals = 2) |>
    fmt_number(columns = "distance", decimals = 1) |>
    data_color(columns = "moons", palette = "blues") |>
    tab_style((text = (weight = "bold",),), [(body = (columns = "moons", rows = (where = ("moons", ">", 50),)),)]) |>
    tab_footnote("Moons confirmed by 2025.", [(columnLabels = "moons",)]) |>
    tab_source_note("NASA, Planetary Fact Sheet")

print(render(t))
