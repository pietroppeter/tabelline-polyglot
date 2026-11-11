// The planets table, the one every port of tabelline draws.
import tabelline.*

case class Planet(planet: String, `type`: String, diameter: Int, mass: Double, distance: Double, moons: Int)

val planets = List(
  Planet("Mercury", "Terrestrial", 4879, 0.33, 57.9, 0),
  Planet("Venus", "Terrestrial", 12104, 4.87, 108.2, 0),
  Planet("Earth", "Terrestrial", 12756, 5.97, 149.6, 1),
  Planet("Mars", "Terrestrial", 6792, 0.642, 228.0, 2),
  Planet("Jupiter", "Gas giant", 142984, 1898.0, 778.5, 95),
  Planet("Saturn", "Gas giant", 120536, 568.0, 1432.0, 146),
  Planet("Uranus", "Ice giant", 51118, 86.8, 2867.0, 28),
  Planet("Neptune", "Ice giant", 49528, 102.0, 4515.0, 16)
)

@main def main(args: String*): Unit =
  val table = Table(planets)
    .stub("planet")
    .groupBy("type")
    .id("planets")
    .header("The planets", md"of the *Solar System*")
    .spanner("Size", "diameter", "mass")
    .labels(
      "diameter" -> "Diameter (km)",
      "mass" -> "Mass (10²⁴ kg)",
      "distance" -> "From the Sun (10⁶ km)",
      "moons" -> "Moons"
    )
    .format("diameter")(Format.Integer)
    .format("mass")(Format.Number(decimals = 2))
    .format("distance")(Format.Number(decimals = 1))
    .colorScale("moons")(Palette.Blues)
    .style(Style.Bold)(Location.Body(Seq("moons"), col("moons") > 50))
    .footnote("Moons confirmed by 2025.")(Location.ColumnLabels("moons"))
    .sourceNote("NASA, Planetary Fact Sheet")
  val drawn = if args.headOption.contains("text") then table.text else table.html
  drawn match
    case Right(out) =>
      System.out.write(out.getBytes("UTF-8"))
      System.out.flush()
    case Left(TabellineError(why)) =>
      System.err.println(why)
      sys.exit(1)
