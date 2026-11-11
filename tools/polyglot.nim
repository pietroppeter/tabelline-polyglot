## Builds libtabelline, runs every port's planets example, and checks that each prints the same
## HTML as tabelline itself (nim/planets.nim). Prints the result as a tabelline table.
##
##   nim r tools/polyglot.nim            # everything it finds a toolchain for
##   nim r tools/polyglot.nim c zig      # some of them
##
## tabelline comes from deps/ (`sh tools/setup.sh`, put on the path by nim.cfg), or from
## TABELLINE_SRC (a checkout's src/). Toolchains come from the PATH, or from these variables: ZIG (a command, default `zig`), JULIA, JAVA_HOME, ERL_BIN (the
## bin/ of Erlang/OTP 27+), GLEAM, ELIXIR_BIN.

import std/[os, osproc, strutils, times, monotimes, sequtils, math]
import tabelline

let root = currentSourcePath().parentDir.parentDir
let build = root / "build"
let outDir = root / "out"
let src = getEnv("TABELLINE_SRC")

proc tool(env, default: string): string = getEnv(env, default)
let erlBin = getEnv("ERL_BIN")
let erl = if erlBin.len > 0: erlBin / "erl" else: "erl"
let erlc = if erlBin.len > 0: erlBin / "erlc" else: "erlc"
let javaHome = getEnv("JAVA_HOME")
let java = if javaHome.len > 0: javaHome / "bin" / "java" else: "java"
let javac = if javaHome.len > 0: javaHome / "bin" / "javac" else: "javac"
let elixirBin = getEnv("ELIXIR_BIN")
let elixir = if elixirBin.len > 0: elixirBin / "elixir" else: "elixir"

proc pathWith(dirs: varargs[string]): string =
  (dirs.toSeq.filterIt(it.len > 0) & @[getEnv("PATH")]).join($PathSep)

proc erlInclude(): string =
  ## erl_nif.h: in the Erlang/OTP the BEAM ports run on (its root, asked to erl itself)
  let (o, code) = execCmdEx("export PATH=" & quoteShell(pathWith(erlBin)) &
    "; erl -noshell -eval 'io:format(\"~s\", [code:root_dir()]), halt().'")
  if code == 0: o.strip / "usr" / "include" else: ""

type Port = object
  name, how: string
  steps: seq[string]   # build commands
  run: string          # prints the table's HTML

let nimc = "nim c --hints:off -d:release" & (if src.len > 0: " --path:" & quoteShell(src) else: "")
let ports = @[
  Port(name: "nim", how: "tabelline itself, the reference",
       steps: @[nimc & " -o:build/planets_nim nim/planets.nim"], run: "build/planets_nim"),
  Port(name: "spec", how: "C, layer 1: the JSON spec in one call",
       steps: @["gcc -O2 -Icapi c/spec.c -Lbuild -ltabelline -Wl,-rpath,'$ORIGIN' -o build/spec_c"],
       run: "build/spec_c spec/planets.json"),
  Port(name: "c", how: "C, layer 2: typed columns, one verb at a time",
       steps: @["gcc -O2 -Icapi c/planets.c -Lbuild -ltabelline -Wl,-rpath,'$ORIGIN' -o build/planets_c"],
       run: "build/planets_c"),
  Port(name: "zig", how: "extern fns, arguments written by std.json",
       steps: @[tool("ZIG", "zig") & " build-exe zig/planets.zig -lc -Lbuild -ltabelline -rpath '$ORIGIN' -femit-bin=build/planets_zig"],
       run: "build/planets_zig"),
  Port(name: "rust", how: "extern \"C\", a builder, list! and args! macros",
       steps: @["cd rust && cargo build --offline --release --quiet --example planets"],
       run: "rust/target/release/examples/planets"),
  Port(name: "julia", how: "ccall; one function per verb, made at load time",
       steps: @[], run: tool("JULIA", "julia") & " --startup-file=no julia/planets.jl"),
  Port(name: "jvm", how: "Java 22+ foreign function API (no JNI)",
       steps: @[javac & " -d build/jvm jvm/src/tabelline/Tabelline.java jvm/src/Planets.java"],
       run: java & " --enable-native-access=ALL-UNNAMED -Dtabelline.lib=build/libtabelline.so -cp build/jvm Planets"),
  Port(name: "erlang", how: "one NIF, the spec written by OTP's json",
       steps: @["mkdir -p build/beam/priv build/beam/ebin",
                "gcc -O2 -shared -fPIC -Icapi -I" & quoteShell(erlInclude()) &
                  " beam/c_src/tabelline_nif.c -Lbuild -ltabelline -Wl,-rpath," & quoteShell(build) &
                  " -o build/beam/priv/tabelline_nif.so",
                erlc & " -o build/beam/ebin beam/src/tabelline_nif.erl beam/src/tabelline.erl beam/src/planets.erl"],
       run: erl & " -noshell -pa build/beam/ebin -eval 'planets:main(), halt().'"),
  Port(name: "gleam", how: "a table as a Gleam value, the same NIF",
       steps: @["cd gleam && " & tool("GLEAM", "gleam") & " build"],
       run: "TABELLINE_NIF_DIR=build/beam/priv " & erl & " -noshell -pa gleam/build/dev/erlang/tabelline/ebin -eval 'planets:main(), halt().'"),
  Port(name: "elixir", how: "keyword lists and pipes, the same NIF",
       steps: @[], run: "TABELLINE_NIF_DIR=build/beam/priv ELIXIR_ERL_OPTIONS=+fnu " & elixir & " -pa build/beam/ebin elixir/planets.exs")]

proc sh(cmd: string): (string, int) =
  let env = pathWith(erlBin, elixirBin)
  execCmdEx("export PATH=" & quoteShell(env) & "; cd " & quoteShell(root) & " && " & cmd)

createDir build
createDir outDir
let wanted = commandLineParams()
echo "libtabelline: ", nimc & " --app:lib -d:useMalloc -o:build/libtabelline.so capi/tabelline_c.nim"
let (libOut, libCode) = sh(nimc & " --app:lib -d:useMalloc -o:build/libtabelline.so capi/tabelline_c.nim")
if libCode != 0: quit "libtabelline did not build:\n" & libOut

var names, hows, results: seq[string]
var ms: seq[float]
var reference = ""
for p in ports:
  if wanted.len > 0 and p.name notin wanted and p.name != "nim": continue
  var failed = ""
  for s in p.steps:
    let (o, code) = sh(s)
    if code != 0: (failed = "build failed: " & o.strip.splitLines[^1]; break)
  var took = NaN
  if failed.len == 0:
    let t0 = getMonoTime()
    let (o, code) = sh(p.run & " > out/" & p.name & ".html")
    took = float((getMonoTime() - t0).inMicroseconds) / 1000
    if code != 0: failed = "run failed: " & o.strip
  let html = if failed.len == 0: readFile(outDir / p.name & ".html") else: ""
  if p.name == "nim": reference = html
  names.add p.name
  hows.add p.how
  ms.add took
  results.add(if failed.len > 0: failed elif html == reference: "same HTML" else: "DIFFERENT")

let summary = tableData:
  port: names
  how: hows
  ms: ms
  result: results
let report = tabella(summary, rownameCol = "port"):
  tabHeader "tabelline in other languages", "the planets table, built and checked"
  colsLabel:
    how: "How"
    ms: "Run (ms)"
    result: "Result"
  fmtNumber "ms", decimals = 0
  subMissing "ms", missingText = "—"
  tabSourceNote "Run time includes starting the program (the JVM, the BEAM, Julia)."
echo report
var tsv = "port\thow\tms\tresult\n"
for i, n in names: tsv.add n & "\t" & hows[i] & "\t" & (if ms[i].isNaN: "" else: $int(ms[i])) & "\t" & results[i] & "\n"
if wanted.len == 0: writeFile(root / "results.tsv", tsv)  # read by the devlog post
if results.anyIt(it != "same HTML"): quit 1
