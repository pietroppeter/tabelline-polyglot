## The reference: the table every port draws, written in tabelline itself.
import tabelline

let planets = tableData:
  planet: ["Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"]
  `type`: ["Terrestrial", "Terrestrial", "Terrestrial", "Terrestrial", "Gas giant", "Gas giant", "Ice giant", "Ice giant"]
  diameter: [4879, 12104, 12756, 6792, 142984, 120536, 51118, 49528]
  mass: [0.33, 4.87, 5.97, 0.642, 1898.0, 568.0, 86.8, 102.0]
  distance: [57.9, 108.2, 149.6, 228.0, 778.5, 1432.0, 2867.0, 4515.0]
  moons: [0, 0, 1, 2, 95, 146, 28, 16]

let t = tabella(planets, rownameCol = "planet", groupnameCol = "type", id = "planets"):
  tabHeader "The planets", md"of the *Solar System*"
  tabSpanner "Size", ["diameter", "mass"]
  colsLabel:
    diameter: "Diameter (km)"
    mass: "Mass (10²⁴ kg)"
    distance: "From the Sun (10⁶ km)"
    moons: "Moons"
  fmtInteger "diameter"
  fmtNumber "mass", decimals = 2
  fmtNumber "distance", decimals = 1
  dataColor "moons", palette = palette("blues")
  tabStyle style.text(weight = "bold"), loc.body("moons", where(it["moons"] > 50))
  tabFootnote "Moons confirmed by 2025.", loc.columnLabels("moons")
  tabSourceNote "NASA, Planetary Fact Sheet"

stdout.write t.toHtml
