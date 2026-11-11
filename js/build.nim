## Builds tabelline for JavaScript: `nim js` on `tabelline_js.nim`, written as an ES module into
## the Gleam package (`gleam/src/tabelline_nim.mjs`, not committed), where `tabelline_ffi.mjs`
## imports it.
##
##   nim r js/build.nim                       # lean: no icons, no big datasets (1.8 MB, 260 KB gzipped)
##   nim r js/build.nim --icons --datasets    # everything (3.8 MB, 860 KB gzipped)
##   nim r js/build.nim --debug               # not minified by nim's release mode, with stack traces
##
## The icons and the datasets but planets and exibble are left out unless asked for: a binding
## that can call every verb from JSON keeps everything, and they are most of the weight.
import std/[os, osproc, parseopt]

let root = currentSourcePath.parentDir.parentDir
var icons, datasets, debug = false
for kind, key, val in getopt():
  if kind == cmdLongOption:
    case key
    of "icons": icons = true
    of "datasets": datasets = true
    of "debug": debug = true
    else: quit "unknown option --" & key
let tabellineSrc = getEnv("TABELLINE_SRC")  # else the path in nim.cfg (deps/tabelline/src)

let nimOut = root / "build" / "js" / "tabelline_nim.js"
createDir(nimOut.parentDir)
var cmd = "nim js --hints:off --warnings:off" & (if debug: "" else: " -d:release") &
  " -d:tabellineIcons=" & $icons & " -d:tabellineDatasets=" & $datasets &
  (if tabellineSrc.len > 0: " --path:" & quoteShell(tabellineSrc) else: "") &
  " -o:" & quoteShell(nimOut) & " " & quoteShell(root / "js" / "tabelline_js.nim")
echo "$ ", cmd
let (output, code) = execCmdEx(cmd, workingDir = root)
if code != 0: quit output
# `nim js` writes a script; the Gleam FFI imports a module.
let target = root / "gleam" / "src" / "tabelline_nim.mjs"
writeFile(target, "// tabelline compiled by nim js (js/build.nim). Not committed: rebuild it.\n" &
  readFile(nimOut) & "\nexport { tabelline_render };\n")
echo target.relativePath(root), ": ", getFileSize(target) div 1024, " KB",
  (if icons: ", icons" else: ""), (if datasets: ", datasets" else: "")
