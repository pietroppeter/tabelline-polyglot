## libtabelline: tabelline behind a C ABI, for every language that can call C.
##
## Two layers, the simplest first (tabelline.h has the C declarations):
##
## 1. One call: `tbl_render_spec(spec, format)` takes the whole table as JSON (the data, the
##    stub, the verbs) and returns it rendered. Strings in, a string out.
## 2. A table you build: `tbl_new()`, columns from typed arrays (`tbl_add_doubles`, ...), the stub
##    (`tbl_set(t, "rownameCol", "planet")`), one verb at a time (`tbl_verb(t, "fmtNumber", "{\"decimals\": 3}")`), then
##    `tbl_render(t, format)` and `tbl_drop(t)`. Data never goes through JSON; arguments do.
##
## Formats: "html" (the table with its style), "page" (a whole HTML page), "text", "markdown".
## Errors: a call returns NULL or -1, and `tbl_error()` says why (until the next call).
## Strings returned by the library are freed with `tbl_free`.

import std/[json, math]
import tabelline
import verbs_json, spec

const libVersion = "0.0.1 (tabelline 0.2.0)"

proc c_malloc(size: csize_t): pointer {.importc: "malloc", header: "<stdlib.h>".}
proc c_free(p: pointer) {.importc: "free", header: "<stdlib.h>".}

var lastError {.threadvar.}: string

proc toC(s: string): cstring =
  ## A copy of `s` in memory from malloc, for the caller to free with tbl_free.
  let p = cast[cstring](c_malloc(csize_t(s.len + 1)))
  if s.len > 0: copyMem(p, unsafeAddr s[0], s.len)
  cast[ptr UncheckedArray[char]](p)[s.len] = '\0'
  p

proc render(t: Tabella, format: string): string =
  case format
  of "", "html": t.toHtml
  of "page": t.toHtml(makePage = true)
  of "text": t.toText
  of "markdown", "md": t.toMarkdown
  else: raise newException(ValueError, "unknown format " & format & " (html, page, text, markdown)")

# --------------------------------------------------------------------------- layer 1: one call

proc tbl_version(): cstring {.exportc, dynlib, cdecl.} = libVersion

proc tbl_error(): cstring {.exportc, dynlib, cdecl.} = cstring(lastError)

proc tbl_free(s: cstring) {.exportc, dynlib, cdecl.} =
  if s != nil: c_free(s)

proc tbl_render_spec(spec, format: cstring): cstring {.exportc, dynlib, cdecl.} =
  try:
    lastError = ""
    toC(tabellaFromSpec(parseJson($spec)).render($format))
  except Exception as e:
    lastError = e.msg
    nil

proc tbl_verbs(): cstring {.exportc, dynlib, cdecl.} =
  ## Every verb form the library takes, as JSON: [{"verb": "fmtNumber", "params": [...],
  ## "required": [...]}]. A binding can check its names against it, or be generated from it.
  var a = newJArray()
  for (verb, params, required, ok) in verbForms():
    if ok: a.add %*{"verb": verb, "params": params, "required": required}
  toC($a)

# ----------------------------------------------------------------------- layer 2: a table you build

type
  Handle = ref object
    data: TableData
    rowname, groupname, id, locale: string
    started: bool
    t: Tabella

proc tbl_new(): pointer {.exportc, dynlib, cdecl.} =
  ## A new, empty table. Free it with tbl_drop.
  let h = Handle(data: toTableData(newSeq[(string, seq[Value])]()))
  GC_ref(h)
  cast[pointer](h)

proc tbl_drop(p: pointer) {.exportc, dynlib, cdecl.} =
  if p != nil: GC_unref(cast[Handle](p))

template guard(body: untyped): cint =
  try:
    lastError = ""
    body
    cint(0)
  except Exception as e:
    lastError = e.msg
    cint(-1)

proc addCol(p: pointer, name: cstring, values: seq[Value]): cint =
  guard:
    let h = cast[Handle](p)
    if h.started: raise newException(ValueError, "add the columns before the first verb")
    h.data.addColumn($name, values)

proc tbl_add_doubles(p: pointer, name: cstring, values: ptr UncheckedArray[cdouble], n: csize_t): cint {.exportc, dynlib, cdecl.} =
  ## A number column; NaN is a missing value.
  var vs = newSeq[Value](n)
  for i in 0 ..< int(n): vs[i] = (if values[i].isNaN: null() else: toValue(float(values[i])))
  addCol(p, name, vs)

proc tbl_add_ints(p: pointer, name: cstring, values: ptr UncheckedArray[int64], n: csize_t): cint {.exportc, dynlib, cdecl.} =
  var vs = newSeq[Value](n)
  for i in 0 ..< int(n): vs[i] = toValue(int(values[i]))
  addCol(p, name, vs)

proc tbl_add_bools(p: pointer, name: cstring, values: ptr UncheckedArray[uint8], n: csize_t): cint {.exportc, dynlib, cdecl.} =
  var vs = newSeq[Value](n)
  for i in 0 ..< int(n): vs[i] = toValue(values[i] != 0)
  addCol(p, name, vs)

proc tbl_add_strings(p: pointer, name: cstring, values: ptr UncheckedArray[cstring], n: csize_t): cint {.exportc, dynlib, cdecl.} =
  ## A text column; NULL is a missing value.
  var vs = newSeq[Value](n)
  for i in 0 ..< int(n): vs[i] = (if values[i] == nil: null() else: toValue($values[i]))
  addCol(p, name, vs)

proc tbl_add_json(p: pointer, name, values: cstring): cint {.exportc, dynlib, cdecl.} =
  ## A column from a JSON array, for values of any kind (lists and records too).
  var vs: seq[Value]
  let r = guard:
    for v in parseJson($values).elems: vs.add jsonValue(v)
  if r != 0: return r
  addCol(p, name, vs)

proc tbl_set(p: pointer, key, value: cstring): cint {.exportc, dynlib, cdecl.} =
  ## A setting of the table, before the first verb: "rownameCol" (the stub), "groupnameCol"
  ## (the row groups), "id" (the HTML id, random if not set), "locale".
  guard:
    let h = cast[Handle](p)
    if h.started: raise newException(ValueError, "set " & $key & " before the first verb")
    let v = if value == nil: "" else: $value
    case norm($key)
    of "rownamecol", "rowname", "stub": h.rowname = v
    of "groupnamecol", "groupname", "groups": h.groupname = v
    of "id": h.id = v
    of "locale": h.locale = v
    else: raise newException(ValueError, "unknown setting " & $key)

proc start(h: Handle) =
  if not h.started:
    h.t = initTabella(h.data, rownameCol = h.rowname, groupnameCol = h.groupname, id = h.id, locale = h.locale)
    h.started = true

proc tbl_verb(p: pointer, verb, args: cstring): cint {.exportc, dynlib, cdecl.} =
  ## Applies one verb; `args` is a JSON array (positional), object (named), or NULL.
  guard:
    let h = cast[Handle](p)
    h.start
    let a = if args == nil or args[0] == '\0': Args() else: toArgs(parseJson($args))
    h.t = h.t.applyVerb($verb, a)

proc tbl_render(p: pointer, format: cstring): cstring {.exportc, dynlib, cdecl.} =
  try:
    lastError = ""
    let h = cast[Handle](p)
    h.start
    toC(h.t.render($format))
  except Exception as e:
    lastError = e.msg
    nil
