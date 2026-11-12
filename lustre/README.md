# tabelline_lustre

tabelline's tables in a [Lustre](https://hexdocs.pm/lustre/) app: a table is an element.

```gleam
import tabelline_lustre

fn view(model: Model) -> Element(Msg) {
  html.main([], [controls(model), tabelline_lustre.view(planets(model))])
}
```

- `view(table)` draws the table as HTML, in a `div` with the class `tabelline`;
  `view_with(table, attributes)` adds attributes. tabelline escapes every value it writes, so its
  HTML goes in the page as it is (with Lustre's `unsafe_raw_html`, kept out of sight here).
- `view_text(table)` and `view_markdown(table)` draw it as text, in a `pre`.
- A table that cannot be drawn is a paragraph that says why (`tabelline.describe_error`).

It is its own package, so that `tabelline` (`../gleam/`) keeps no dependencies. It runs on both
targets: in a browser, tabelline compiled by `nim js` draws the table; on the BEAM, the NIF.

## The demo

`demo/` is a Lustre app with two tables, built again at every change: the planets, with a title,
a locale, the decimals of the mass, a palette and a line for bold moons to change, as HTML, text
or Markdown; and a look at one of tabelline's datasets, with how many of its first and last rows
to show. `nim r lustre/demo/build.nim` (from the root) builds it into one file,
`demo/dist/index.html`, in four steps:

1. `nim r js/build.nim --datasets`: tabelline for JavaScript, with the datasets and without the
   icons, as `gleam/src/tabelline_nim.mjs`.
2. `gleam build` in `demo/`: the app, tabelline, this package, Lustre and Gleam's standard
   library, as JavaScript modules.
3. esbuild follows the imports from `demo/entry.mjs` and writes one minified script.
4. The script goes in `demo/page.html`, which holds the style.

The page weighs 2.3 MB, about 400 KB gzipped; almost all of it is tabelline's locales and
datasets.

In a sandbox that cannot reach Hex: the Gleam binary from GitHub's releases, the dependencies
cloned with git (lustre v5.7.1, stdlib v1.0.5, json v3.1.0, erlang v1.3.0, otp v1.3.0, houdini
v1.2.1 from giacomocavalieri/houdini, exception v2.1.1) and given to `gleam.toml` as paths, for
the build only. The committed `gleam.toml` names them as Hex packages, and the manifests are not
committed.
