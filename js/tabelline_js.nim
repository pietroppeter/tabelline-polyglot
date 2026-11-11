## libtabelline for JavaScript: tabelline compiled with `nim js`, one function, the same JSON
## spec as the C ABI's layer 1 (`capi/spec.nim`).
##
##   nim js -d:release -o:build/tabelline_nim.js js/tabelline_js.nim
##
## `tabelline_render(spec, format)` returns `{ok: true, value: html}` or `{ok: false, value: why}`.
## `nim js` writes a script, not a module: the build appends `export { tabelline_render };`.
import std/[json, jsffi]
import ../capi/spec
import tabelline

proc tabellineRender(spec, format: cstring): JsObject {.exportc: "tabelline_render".} =
  result = newJsObject()
  try:
    let t = tabellaFromSpec(parseJson($spec))
    let output = case $format
      of "", "html": t.toHtml
      of "page": t.toHtml(makePage = true)
      of "text": t.toText
      of "markdown", "md": t.toMarkdown
      else: raise newException(ValueError, "unknown format " & $format & " (html, page, text, markdown)")
    result.ok = true
    result.value = cstring(output)
  except CatchableError as e:
    result.ok = false
    result.value = cstring(e.msg)
