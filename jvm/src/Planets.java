import static tabelline.Tabelline.*;
import java.util.List;

public class Planets {
    public static void main(String[] a) {
        try (var t = table()) {
            t.strings("planet", "Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune")
             .strings("type", "Terrestrial", "Terrestrial", "Terrestrial", "Terrestrial",
                      "Gas giant", "Gas giant", "Ice giant", "Ice giant")
             .ints("diameter", 4879, 12104, 12756, 6792, 142984, 120536, 51118, 49528)
             .doubles("mass", 0.33, 4.87, 5.97, 0.642, 1898.0, 568.0, 86.8, 102.0)
             .doubles("distance", 57.9, 108.2, 149.6, 228.0, 778.5, 1432.0, 2867.0, 4515.0)
             .ints("moons", 0, 0, 1, 2, 95, 146, 28, 16)
             .set("rownameCol", "planet")
             .set("groupnameCol", "type")
             .set("id", "planets")
             .verb("tabHeader", List.of("The planets", md("of the *Solar System*")))
             .verb("tabSpanner", List.of("Size", List.of("diameter", "mass")))
             .verb("colsLabel", args("labels", args(
                 "diameter", "Diameter (km)",
                 "mass", "Mass (10²⁴ kg)",
                 "distance", "From the Sun (10⁶ km)",
                 "moons", "Moons")))
             .verb("fmtInteger", List.of("diameter"))
             .verb("fmtNumber", args("columns", "mass", "decimals", 2))
             .verb("fmtNumber", args("columns", "distance", "decimals", 1))
             .verb("dataColor", args("columns", "moons", "palette", "blues"))
             .verb("tabStyle", List.of(args("text", args("weight", "bold")),
                 List.of(args("body", args("columns", "moons", "rows", args("where", List.of("moons", ">", 50)))))))
             .verb("tabFootnote", List.of("Moons confirmed by 2025.", List.of(args("columnLabels", "moons"))))
             .verb("tabSourceNote", List.of("NASA, Planetary Fact Sheet"));
            System.out.writeBytes(t.render("html").getBytes(java.nio.charset.StandardCharsets.UTF_8));
        }
    }
}
