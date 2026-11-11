# 📊 tabelline - great tables for Gleam

> A proof of concept: the API is here to be argued with.

R has [gt](https://gt.rstudio.com) and Python has
[Great Tables](https://posit-dev.github.io/great-tables/): libraries for the tables you read,
the ones in a report or a paper, with a title, row groups, spanners over the columns, numbers
written the way people read them, and footnotes. Gleam has printers that draw rows of strings
with borders, but nothing like that yet.

This package is gt's grammar in Gleam: a table is built from your own records, one step at a
time, with `|>`, and every part of it is a Gleam type.

```gleam
import gleam/io
import tabelline.{Blues, Markdown, Plain}
import tabelline/column
import tabelline/format
import tabelline/location
import tabelline/rows.{Greater}
import tabelline/style

pub type Planet {
  Planet(name: String, kind: Kind, diameter: Int, mass: Float, moons: Int)
}

pub fn main() {
  let assert Ok(table) =
    planets()
    |> tabelline.from_list
    |> column.string("planet", fn(planet) { planet.name })
    |> column.string("type", fn(planet) { kind_name(planet.kind) })
    |> column.int("diameter", fn(planet) { planet.diameter })
    |> column.float("mass", fn(planet) { planet.mass })
    |> column.int("moons", fn(planet) { planet.moons })
    |> tabelline.stub("planet")
    |> tabelline.group_by("type")
    |> tabelline.title(Plain("The planets"))
    |> tabelline.subtitle(Markdown("of the *Solar System*"))
    |> tabelline.spanner(Plain("Size"), over: ["diameter", "mass"])
    |> tabelline.format(["diameter"], with: format.integer())
    |> tabelline.format(["mass"], with: format.number(decimals: 2))
    |> tabelline.colour_scale(["moons"], with: Blues)
    |> tabelline.style([style.bold()], at: [
      location.body(columns: ["moons"], rows: rows.where_int("moons", Greater, 50)),
    ])
    |> tabelline.to_text

  io.println(table)
}
```

```text
                                 The planets
                             of the Solar System
┌─────────┬───────────────┬────────────────┬───────────────────────┬─────────┐
│         │              Size              │                                 │
│         │ Diameter (km) │ Mass (10²⁴ kg) │ From the Sun (10⁶ km) │ Moons^1 │
╞═════════╪═══════════════╪════════════════╪═══════════════════════╪═════════╡
│ Terrestrial                                                                │
├┄┄┄┄┄┄┄┄┄┼┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┼┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┼┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┼┄┄┄┄┄┄┄┄┄┤
│ Mercury │         4,879 │           0.33 │                  57.9 │       0 │
│ Venus   │        12,104 │           4.87 │                 108.2 │       0 │
│ Earth   │        12,756 │           5.97 │                 149.6 │       1 │
│ Mars    │         6,792 │           0.64 │                 228.0 │       2 │
├─────────┼───────────────┼────────────────┼───────────────────────┼─────────┤
│ Gas giant                                                                  │
├┄┄┄┄┄┄┄┄┄┼┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┼┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┼┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┼┄┄┄┄┄┄┄┄┄┤
│ Jupiter │       142,984 │       1,898.00 │                 778.5 │      95 │
│ Saturn  │       120,536 │         568.00 │               1,432.0 │     146 │
├─────────┼───────────────┼────────────────┼───────────────────────┼─────────┤
│ Ice giant                                                                  │
├┄┄┄┄┄┄┄┄┄┼┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┼┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┼┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┼┄┄┄┄┄┄┄┄┄┤
│ Uranus  │        51,118 │          86.80 │               2,867.0 │      28 │
│ Neptune │        49,528 │         102.00 │               4,515.0 │      16 │
└─────────┴───────────────┴────────────────┴───────────────────────┴─────────┘
1 Moons confirmed by 2025.
NASA, Planetary Fact Sheet
```

(The whole example, with the labels, the footnote and the source note, is
[src/planets.gleam](src/planets.gleam): `gleam run -m planets -- text`.)

The same table is HTML with `to_html`, a whole page with `to_page`, and Markdown with
`to_markdown`.

## How it's shaped

- **Your records, not a data frame.** A table is a `Table(row)`, built from a `List(row)` of
  any type. Each column is a name and a function that reads it from a row, so the compiler
  checks every column, and all columns always have the same length.
- **Every part is a type.** Formats (`format.number(decimals: 2)`), styles (`style.bold()`),
  parts of the table (`location.body(columns:, rows:)`), which rows
  (`rows.where_int("moons", Greater, 50)`), palettes (`Blues`) and text (`Plain`, `Markdown`,
  `Html`). Nothing is a string that only fails when the table is drawn, except column names.
- **Nothing happens until it's drawn.** A table is a plain value: keep it, pass it, add a step.
  `to_html` and the others return a `Result`, with an `Error` that says what went wrong
  (`DuplicateColumn`, or `Rejected` with tabelline's reason), and `describe_error` turns it into
  a sentence.
- **No dependencies.** Not even `gleam_stdlib`: the sandbox this was written in could not reach
  Hex. With it, a missing value would be an `Option` instead of a `Result(a, Nil)`.

## How it works

The drawing is done by [tabelline](https://github.com/pietroppeter/tabelline), a Nim library.
The Gleam side writes the table as JSON (its data, its settings and its steps), and on the BEAM
one NIF hands it to `libtabelline`, the same C library every other port of this repository
calls, on a dirty scheduler. `tools/polyglot.nim` at the root checks that this program prints
exactly the same HTML as tabelline itself.

## Running it

From the root of the repository: `nim r tools/polyglot.nim gleam` builds the library, the NIF
and this package, and runs the example. Then, here:

```sh
gleam run -m planets -- text
TABELLINE_NIF_DIR=../build/beam/priv gleam test
gleam docs build
```
