## Builds libtabelline, runs every port's planets example, and checks that each prints the same
## HTML as tabelline itself (nim/planets.nim). Prints the result as a tabelline table.
##
##   nim r tools/polyglot.nim            # everything it finds a toolchain for
##   nim r tools/polyglot.nim c zig      # some of them
##
## tabelline comes from deps/ (`sh tools/setup.sh`, put on the path by nim.cfg), or from
## TABELLINE_SRC (a checkout's src/). Toolchains come from the PATH, or from these variables: ZIG (a command, default `zig`), JULIA, JAVA_HOME, ERL_BIN (the
## bin/ of Erlang/OTP 27+), GLEAM, ELIXIR_BIN. The gleam-js port needs Node too.

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

# Scala 3's compiler, from Maven Central (no sbt or scala-cli needed): these jars, into build/scala/jars.
const scalaJars = [
  "org/scala-lang:scala3-compiler_3:3.10.1", "org/scala-lang:scala3-interfaces:3.10.1",
  "org/scala-lang:tasty-core_3:3.10.1", "org/scala-lang:scala3-library_3:3.10.1",
  "org/scala-lang:scala-library:3.10.1", "org/ow2/asm:asm:9.11.1", "org/ow2/asm:asm-util:9.11.1",
  "org/ow2/asm:asm-tree:9.11.1", "org/ow2/asm:asm-analysis:9.11.1", "org/ow2/asm:asm-commons:9.11.1",
  "org/scala-sbt:compiler-interface:1.12.1", "org/scala-sbt:util-interface:1.12.4"]
proc jarFile(spec: string): string =
  let p = spec.split(':')
  p[1] & "-" & p[2] & ".jar"
proc jarUrl(spec: string): string =
  let p = spec.split(':')
  "https://repo1.maven.org/maven2/" & p[0] & "/" & p[1] & "/" & p[2] & "/" & jarFile(spec)
let scalaFetch = "mkdir -p build/scala/jars && cd build/scala/jars && " & scalaJars.mapIt(
  "{ [ -f " & jarFile(it) & " ] || curl -sSfL --retry 5 --retry-delay 5 -o " & jarFile(it) & " " & jarUrl(it) & "; }").join(" && ")
let scalaCompiler = scalaJars.mapIt("build/scala/jars/" & jarFile(it)).join(":")
let scalaLib = "build/scala/jars/scala-library-3.10.1.jar:build/scala/jars/scala3-library_3-3.10.1.jar"
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
  Port(name: "gleam", how: "a typed table of your own records, the same NIF",
       steps: @["cd gleam && " & tool("GLEAM", "gleam") & " build"],
       run: "TABELLINE_NIF_DIR=build/beam/priv " & erl & " -noshell -pa gleam/build/dev/erlang/tabelline/ebin -eval 'planets:main(), halt().'"),
  Port(name: "gleam-js", how: "the same Gleam, on its JavaScript target: tabelline by nim js",
       steps: @["nim r --hints:off js/build.nim", "cd gleam && " & tool("GLEAM", "gleam") & " build --target javascript"],
       run: "node --input-type=module -e \"import { main } from './gleam/build/dev/javascript/tabelline/planets.mjs'; main()\""),
  Port(name: "go", how: "cgo; a slice of structs, tags name the columns",
       steps: @["cd go && go build -o ../build/planets_go ./examples/planets"], run: "build/planets_go"),
  Port(name: "scala", how: "Scala 3 on the FFM API; columns from a case class",
       steps: @[scalaFetch, "mkdir -p build/scala/classes && " & java & " -cp " & scalaCompiler &
                  " dotty.tools.dotc.Main -encoding UTF-8 -d build/scala/classes -classpath " & scalaLib &
                  " scala/Tabelline.scala scala/Planets.scala"],
       run: java & " --enable-native-access=ALL-UNNAMED -cp build/scala/classes:" & scalaLib & " main"),
  Port(name: "ruby", how: "Fiddle (standard library); a block, every verb a method",
       steps: @[], run: "ruby ruby/planets.rb"),
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
  tabSourceNote "Run time includes starting the program (the JVM, the BEAM, Julia, Node)."
echo report
var tsv = "port\thow\tms\tresult\n"
for i, n in names: tsv.add n & "\t" & hows[i] & "\t" & (if ms[i].isNaN: "" else: $int(ms[i])) & "\t" & results[i] & "\n"
if wanted.len == 0: writeFile(root / "results.tsv", tsv)  # read by the devlog post
if results.anyIt(it != "same HTML"): quit 1
