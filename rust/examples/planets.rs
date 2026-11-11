use tabelline::{args, list, md, Format, Table};

fn main() -> Result<(), tabelline::Error> {
    let t = Table::new()
        .strings("planet", &["Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"])
        .strings("type", &["Terrestrial", "Terrestrial", "Terrestrial", "Terrestrial",
                           "Gas giant", "Gas giant", "Ice giant", "Ice giant"])
        .ints("diameter", &[4879, 12104, 12756, 6792, 142984, 120536, 51118, 49528])
        .floats("mass", &[0.33, 4.87, 5.97, 0.642, 1898.0, 568.0, 86.8, 102.0])
        .floats("distance", &[57.9, 108.2, 149.6, 228.0, 778.5, 1432.0, 2867.0, 4515.0])
        .ints("moons", &[0, 0, 1, 2, 95, 146, 28, 16])
        .set("rownameCol", "planet")
        .set("groupnameCol", "type")
        .set("id", "planets")
        .verb("tab_header", list!["The planets", md("of the *Solar System*")])
        .verb("tab_spanner", list!["Size", ["diameter", "mass"]])
        .verb("cols_label", args! { labels: args! {
            diameter: "Diameter (km)",
            mass: "Mass (10²⁴ kg)",
            distance: "From the Sun (10⁶ km)",
            moons: "Moons",
        } })
        .verb("fmt_integer", list!["diameter"])
        .verb("fmt_number", args! { columns: "mass", decimals: 2 })
        .verb("fmt_number", args! { columns: "distance", decimals: 1 })
        .verb("data_color", args! { columns: "moons", palette: "blues" })
        .verb("tab_style", list![
            args! { text: args! { weight: "bold" } },
            list![args! { body: args! { columns: "moons", rows: args! { r#where: list!["moons", ">", 50] } } }],
        ])
        .verb("tab_footnote", list!["Moons confirmed by 2025.", list![args! { column_labels: "moons" }]])
        .verb("tab_source_note", list!["NASA, Planetary Fact Sheet"]);
    print!("{}", t.render(Format::Html)?);
    Ok(())
}
