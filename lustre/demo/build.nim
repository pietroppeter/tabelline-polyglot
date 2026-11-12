## Builds the demo into one file, `lustre/demo/dist/index.html`: tabelline for JavaScript with
## the datasets (`js/build.nim --datasets`), the Gleam app (`gleam build`), one bundle
## (esbuild), inlined in `page.html`.
##
##   nim r lustre/demo/build.nim
##
## GLEAM and ESBUILD point at the tools when they are not on the PATH.
import std/[os, osproc, strutils]

let root = currentSourcePath.parentDir.parentDir.parentDir
let here = root / "lustre" / "demo"

proc run(cmd: string, dir: string) =
  echo "$ ", cmd
  let (output, code) = execCmdEx(cmd, workingDir = dir)
  if code != 0: quit output

run "nim r --hints:off js/build.nim --datasets", root
run getEnv("GLEAM", "gleam") & " build", here
run getEnv("ESBUILD", "esbuild") & " entry.mjs --bundle --minify --format=esm --log-level=warning --outfile=build/app.js", here
let app = readFile(here / "build" / "app.js").replace("</script", "<\\/script")
createDir(here / "dist")
writeFile(here / "dist" / "index.html", readFile(here / "page.html").replace("/*APP*/", app))
echo "lustre/demo/dist/index.html: ", getFileSize(here / "dist" / "index.html") div 1024, " KB"
