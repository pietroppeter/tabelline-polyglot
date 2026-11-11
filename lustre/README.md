# tabelline in the browser (Gleam, Lustre, `nim js`)

A proof of concept: tabelline compiled to JavaScript with `nim js` (`../js/tabelline_js.nim`,
one exported function on the JSON spec of `../capi/spec.nim`), called from Gleam on its
JavaScript target, inside a [Lustre](https://hexdocs.pm/lustre/) app that builds the planets
table again on every change.

- `src/tabelline.gleam`, `src/tabelline/json.gleam`: the binding of `../gleam/`, with an
  `@external(javascript, ...)` beside each `@external(erlang, ...)`.
- `src/tabelline_ffi.mjs`: the JavaScript side (render, JSON numbers, a clock).
- `src/tabelline_lustre.gleam`: the app (model, update, view).
- `src/planets.gleam`: the polyglot example; `gleam run -m planets` prints the same HTML as
  `nim/planets.nim`.
- `build.nim`: `nim js`, `gleam build`, esbuild, then one file, `dist/index.html`.

```sh
nim r lustre/build.nim   # GLEAM, ESBUILD, TABELLINE_SRC if not on the PATH / in deps
```

tabelline needs two changes to run under `nim js` (a file read in `pictures.nim`; big const
strings bound once with `let` in `localize.nim` and `pictures.nim`), in tabelline's PR with
the devlog post *tabelline in the browser, from Gleam*.

In a sandbox that cannot reach repo.hex.pm: the Gleam binary from GitHub releases, and the
dependencies cloned with git (lustre v5.7.1, stdlib v1.0.5, json v3.1.0, erlang v1.3.0,
otp v1.3.0, houdini v1.2.1, exception v2.1.1) and given as path dependencies in `gleam.toml`.
