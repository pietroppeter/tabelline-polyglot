# tabelline-polyglot

> IT IS CRAZY

[tabelline](https://github.com/pietroppeter/tabelline) (great tables for Nim) is written in Nim,
and Nim compiles to C. So tabelline can be a C library, and every language that calls C can draw
a tabelline table. This repository checks that, end to end, for C, Zig, Rust, Julia, Java,
Scala, Erlang, Gleam, Elixir, Go and Ruby. Each port draws the same table (the
planets), and `tools/polyglot.nim` checks that every one prints the same HTML as tabelline
itself, byte for byte. Nim also compiles to JavaScript, so Gleam can draw the table on its
JavaScript target too, and a web page can build tables with nothing on a server:
[the demo](https://pietroppeter.github.io/tabelline-polyglot/), a Lustre app (`lustre/`).

These are proofs of concept, not ports yet: a working table in each language, for someone to
start a port from, in that language's own style. Two posts in tabelline's devlog tell the why and
the how: [Great tables in every language](https://pietroppeter.github.io/tabelline/devlog/polyglot-survey/)
(what the other languages have) and
[tabelline in eight languages](https://pietroppeter.github.io/tabelline/devlog/polyglot/) (this
code, explained). The code was first written in tabelline's `experiments/polyglot/` and moved
here on 11 Nov 2026.

## The C ABI, in two layers

`capi/tabelline_c.nim` is compiled with `nim c --app:lib` into `libtabelline.so`; `capi/tabelline.h`
declares it.

1. **One call.** `tbl_render_spec(spec, format)`: the whole table as JSON (the data, the stub, the
   verbs) in, the table rendered out. `spec/planets.json` is the planets table.
2. **A table you build.** `tbl_new()`, typed columns (`tbl_add_doubles`, `tbl_add_ints`,
   `tbl_add_strings`, ...), settings (`tbl_set(t, "rownameCol", "planet")`), one verb at a time
   (`tbl_verb(t, "fmtNumber", "{\"columns\": \"mass\", \"decimals\": 2}")`), `tbl_render(t, "html")`,
   `tbl_drop(t)`.

Every verb is there without being written twice: `capi/verbs_json.nim` reads tabelline's verbs'
signatures with a macro and writes, for each overload, the code that converts JSON arguments to
its parameters (93 of the 99 overloads; the rest take a Nim proc). Names ignore case and
underscores, so `fmt_number` is `fmtNumber`. `tbl_verbs()` lists them, as JSON.

## The ports

| folder | how it calls the library |
|---|---|
| `nim/` | the reference: the table in tabelline itself |
| `c/` | `planets.c` (layer 2) and `spec.c` (layer 1, any spec file) |
| `zig/` | `extern fn` declarations (Zig 0.17 has no `@cImport`); arguments are any Zig value, written by `std.json` |
| `rust/` | a crate with no dependencies: `extern "C"`, a builder, and `list!` / `args!` macros for arguments |
| `julia/` | `ccall`; one Julia function per verb (`fmt_number`), made when the module loads from `tbl_verbs()` |
| `jvm/` | Java's foreign function and memory API (Java 22+), no JNI |
| `beam/` | one NIF (`render_spec`, on a dirty scheduler) and an Erlang module writing the spec with OTP 27's `json` |
| `gleam/` | a typed table of your own records, `Table(row)`: columns read from them, formats, styles, rows and errors as Gleam types, with docs and tests; the same NIF ([gleam/README.md](gleam/README.md)) |
| `js/` | tabelline compiled by `nim js`, one function on the spec of layer 1, for `gleam/` on its JavaScript target (the port `gleam-js`) |
| `lustre/` | `tabelline_lustre.view(table)`, a table as a [Lustre](https://hexdocs.pm/lustre/) element, and `demo/`, a Lustre app that builds its tables again at every change, in the browser |
| `elixir/` | keyword lists and pipes; the same NIF |
| `go/` | cgo; a table from a slice of structs (tags name the columns), steps that keep the first error, as `bufio.Scanner` does |
| `scala/` | Scala 3 on Java's foreign function API: columns from a case class (a `Mirror`), `md"..."`, `col("moons") > 50`, `Either` for errors |
| `ruby/` | Fiddle, from the standard library: a block where every one of tabelline's verbs is a method (`fmt_number :mass, decimals: 2`) |

## Run it

```sh
sh tools/setup.sh                 # Nim and atlas if missing, and tabelline (pinned) into deps/
nim r tools/polyglot.nim          # every port
nim r tools/polyglot.nim zig rust # some of them (and Nim, the reference)
```

tabelline is a pinned dependency (`atlas.lock`, the `build` feature of `tabelline_polyglot.nimble`),
cloned into `deps/` and put on the path by `nim.cfg`; `TABELLINE_SRC=<a checkout>/src` uses
another one. CI (`.github/workflows/ports.yml`) runs every port on every push.

Toolchains come from the `PATH` or from `ZIG`, `JULIA`, `JAVA_HOME`, `ERL_BIN` (Erlang/OTP 27 or
later), `GLEAM`, `ELIXIR_BIN`; Go and Ruby from the `PATH`. Scala needs only Java: its compiler's
jars are downloaded from Maven Central into `build/scala/jars`. Checked on 11 Nov 2026 with Nim
2.2.4, gcc 13.3, Zig 0.17.1, Rust 1.97, Julia 1.13.3, Java 25, Scala 3.10.1, Erlang/OTP 29,
Gleam 1.19.1, Elixir 1.20.5, Go 1.24 and Ruby 3.3 (`results.tsv`).

The demo, one HTML file: `nim r lustre/demo/build.nim` (Gleam and esbuild on the `PATH`, or in
`GLEAM` and `ESBUILD`), into `lustre/demo/dist/index.html`; CI (`.github/workflows/demo.yml`)
publishes it on GitHub Pages.

The bindings' own tests: `gleam test` in `gleam/` (with `TABELLINE_NIF_DIR=../build/beam/priv`;
`gleam test --target javascript` after `nim r js/build.nim`),
`go test ./...` in `go/`, `ruby ruby/test/test_tabelline.rb`.

## Layout

```text
tabelline-polyglot/
  capi/      libtabelline + tabelline.h (layer 1: the spec; layer 2: handles and verbs)
  spec/      the JSON spec: planets.json
  nim/       the reference, in tabelline itself
  c/ zig/ rust/ julia/ jvm/ scala/ beam/ gleam/ elixir/ go/ ruby/   a binding and an example each
  js/        tabelline for JavaScript (nim js), for gleam/ on its JavaScript target
  lustre/    tabelline_lustre (a table as a Lustre element) and demo/, the app in the browser
  tools/     setup.sh; polyglot.nim: build everything, run every example, compare with Nim
```

tabelline's devlog post imports `capi/` from here (a pinned dependency of its docs), to draw the
planets table from the spec in the page and to show this code.

## What a real port would add

Packages for each language's registry (crates.io, Hex, Maven, Julia's General registry), the
library built for each platform, a documented spec with a JSON schema, and errors and types in
each language's own style. Most of all, someone who writes that language every day.
