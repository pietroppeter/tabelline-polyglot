## Builds the Lustre demo into one file, dist/index.html: tabelline to JavaScript (`nim js`),
## the Gleam app (`gleam build`), one bundle (esbuild), inlined in page.html.
##
##   nim r lustre/build.nim          # from the repository's root
##
## GLEAM and ESBUILD point at the tools when they are not on the PATH.
import std/[os, osproc, strutils]

let root = currentSourcePath.parentDir.parentDir
let here = root / "lustre"
let gleam = getEnv("GLEAM", "gleam")
let esbuild = getEnv("ESBUILD", "esbuild")
let tabellineSrc = getEnv("TABELLINE_SRC")  # else the path in nim.cfg (deps/tabelline/src)

proc run(cmd: string, dir = root) =
  echo "$ ", cmd
  let (output, code) = execCmdEx(cmd, workingDir = dir)
  if code != 0:
    echo output
    quit "failed: " & cmd

createDir(root / "build")
run "nim js -d:release --hints:off" &
    (if tabellineSrc.len > 0: " --path:" & quoteShell(tabellineSrc) else: "") &
    " -o:build/tabelline_nim.js js/tabelline_js.nim"
# `nim js` writes a script; the Gleam FFI imports a module.
writeFile(here / "src" / "tabelline_nim.mjs",
          readFile(root / "build" / "tabelline_nim.js") & "\nexport { tabelline_render };\n")
run gleam & " build", here
run esbuild & " entry.mjs --bundle --minify --format=esm --log-level=warning --outfile=build/app.js", here
let app = readFile(here / "build" / "app.js").replace("</script", "<\\/script")
createDir(here / "dist")
writeFile(here / "dist" / "index.html", readFile(here / "page.html").replace("/*APP*/", app))
echo "dist/index.html: ", getFileSize(here / "dist" / "index.html") div 1024, " KB"
