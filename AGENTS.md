# Working on tabelline-polyglot

Notes for coding agents (and people). What the repository is, and how to run it, is in README.md.

- `sh tools/setup.sh` first, in a fresh checkout or sandbox: Nim and atlas if missing, and
  tabelline at the commit in `atlas.lock`, into `deps/` (not committed).
- To move to a newer tabelline: `atlas update tabelline` (or edit the `build` feature), run every
  port, then `atlas pin --feature=build` and commit `atlas.lock` and `nim.cfg`. atlas 0.16 also
  writes tabelline's own docs dependencies (nimib, nimibook, nanuq) into `atlas.lock`, with no
  directory and a wrong commit: delete those entries, or `atlas rep` fails.
- `nim r tools/polyglot.nim` must print *same HTML* for every port, in CI too. A change to the C
  ABI (`capi/`) changes `capi/tabelline.h` and every binding that uses it, in the same PR.
- Run every port before pushing, with the results in `results.tsv` (written by a run with no
  arguments): tabelline's devlog post *tabelline in eight languages* reads it, and shows the code
  of the ports by file and by the lines between two markers (`start`, `stop` in
  `docs/devlog/polyglot.nim` in tabelline). Renaming a file or changing those lines breaks the
  post at its next pin: check it there.
- Each binding is written in its language's own style, with no dependencies beyond the language
  and its standard library, so it runs in a sandbox that cannot reach package registries.
- Prefer Nim for tooling. Nothing goes to `main` without Pietro's go; one PR per change.

## Sandbox toolchains

Package hosts are often blocked in a coding-agent sandbox. What worked (11 Nov 2026):
Zig with `pip install ziglang` (`ZIG="python3 -m ziglang"`); Java 25 from apt; Erlang/OTP 29,
Gleam, Elixir and Julia from conda-forge `.conda` files (conda.anaconda.org; unzip, then
`tar --zstd`, and replace the build prefix in the files that hold it); Rust and gcc preinstalled.
Point `ERL_BIN`, `GLEAM`, `ELIXIR_BIN`, `JULIA`, `JAVA_HOME` at them.
