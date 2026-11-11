## Every verb of tabelline, callable with JSON arguments.
##
## `applyVerb(t, "fmtNumber", args)` calls `fmtNumber` with the arguments of `args`: a JSON array
## (positional, in the order of the Nim signature after the table) or a JSON object (named). The
## dispatch is not written by hand: the macro `verbsFromSignatures` reads the signature of every
## verb (its parameters, their types and defaults) and writes, for each overload, the code that
## converts the JSON arguments and calls it. A parameter whose type has no `conv` (a Nim proc, a
## generic) leaves that overload out. So when tabelline gains a verb, the C API has it after a
## rebuild.
##
## Names are compared the way Nim compares them, ignoring case and underscores: `fmt_number`,
## `fmtNumber` and `FmtNumber` are the same verb, and `use_seps` is `useSeps`. Each language
## writes the names in its own style.

import std/[json, macros, strutils, math, tables, sequtils]
import tabelline

type
  ArgError* = object of ValueError
    ## The arguments don't fit one form of a verb (wrong kind, unknown name, missing value).
  Args* = object
    pos*: seq[JsonNode]
    named*: OrderedTable[string, JsonNode]

func norm*(s: string): string =
  ## A name the way Nim compares it: no case, no underscores.
  s.toLowerAscii.replace("_", "")

proc toArgs*(j: JsonNode): Args =
  ## A JSON array is positional arguments, an object named ones, anything else one positional.
  ## Both at once: an object with the positional ones under "_args".
  if j == nil or j.kind == JNull: discard
  elif j.kind == JArray: result.pos = j.elems
  elif j.kind == JObject:
    for k, v in j.fields:
      if k == "_args" and v.kind == JArray: result.pos = v.elems  # positional and named together
      else: result.named[norm(k)] = v
  else: result.pos = @[j]

proc argError(msg: string) {.noreturn.} = raise newException(ArgError, msg)

# ------------------------------------------------------------------------------- JSON -> Nim values

proc conv*(j: JsonNode, T: typedesc[string]): string =
  if j.kind != JString: argError("expected a string, got " & $j)
  j.str
proc conv*(j: JsonNode, T: typedesc[int]): int =
  if j.kind != JInt: argError("expected an integer, got " & $j)
  j.num.int
proc conv*(j: JsonNode, T: typedesc[float]): float =
  case j.kind
  of JInt: j.num.float
  of JFloat: j.fnum
  of JNull: NaN
  else: argError("expected a number, got " & $j)
proc conv*(j: JsonNode, T: typedesc[bool]): bool =
  if j.kind != JBool: argError("expected true or false, got " & $j)
  j.bval
proc conv*[E: enum](j: JsonNode, T: typedesc[E]): E =
  ## An enum by the name of its value, with or without its prefix: "center" or "aCenter".
  let s = norm(conv(j, string))
  for e in E:
    let n = norm($e)
    if n == s or n.endsWith(s) and n.len - s.len <= 3: return e
  argError("expected one of " & $E & ", got " & $j)

proc conv*(j: JsonNode, T: typedesc[Text]): Text =
  ## "plain", {"md": "**bold**"} or {"html": "<b>bold</b>"}.
  case j.kind
  of JString: toText(j.str)
  of JObject:
    if j.hasKey("md"): md(j["md"].getStr)
    elif j.hasKey("html"): html(j["html"].getStr)
    else: argError("a text is a string, {\"md\": ...} or {\"html\": ...}")
  else: argError("expected a text, got " & $j)

proc conv*[T](j: JsonNode, S: typedesc[seq[T]]): seq[T] =
  if j.kind != JArray: argError("expected an array, got " & $j)
  for e in j.elems: result.add conv(e, T)

proc conv*(j: JsonNode, T: typedesc[(float, float)]): (float, float) =
  if j.kind != JArray or j.len != 2: argError("expected [low, high], got " & $j)
  (conv(j[0], float), conv(j[1], float))

proc conv*(j: JsonNode, T: typedesc[ColSel]): ColSel =
  ## "mass", ["mass", "diameter"], {"numeric": true}, {"everything": true}, {"textual": true},
  ## {"startsWith": "x"}, {"endsWith": [...]}, {"containing": ...}, {"positions": [0, 2]}.
  case j.kind
  of JString: return toColSel(j.str)
  of JArray: return toColSel(conv(j, seq[string]))
  of JObject:
    if j.len != 1: argError("a column rule has one key, got " & $j)
    for k, v in j.fields:
      let parts = if v.kind == JArray: conv(v, seq[string]) elif v.kind == JString: @[v.str] else: @[]
      case norm(k)
      of "numeric": return numeric()
      of "textual": return textual()
      of "everything", "all": return everything()
      of "startswith": return startsWith(parts)
      of "endswith": return endsWith(parts)
      of "containing", "contains": return containing(parts)
      of "positions": return positions(conv(v, seq[int]))
      else: argError("unknown column rule " & k)
  else: argError("expected columns, got " & $j)

proc jsonValue*(j: JsonNode): Value =
  ## A JSON value as a tabelline value: numbers, strings, booleans, null, arrays and objects.
  case j.kind
  of JNull: null()
  of JBool: toValue(j.bval)
  of JInt: toValue(j.num.int)
  of JFloat: toValue(j.fnum)
  of JString: toValue(j.str)
  of JArray: (var items: seq[Value]; (for e in j.elems: items.add jsonValue(e)); list(items))
  of JObject: (var f: seq[(string, Value)]; (for k, v in j.fields: f.add (k, jsonValue(v))); record(f))

proc conv*(j: JsonNode, T: typedesc[Value]): Value = jsonValue(j)

proc conv*(j: JsonNode, T: typedesc[RowSel]): RowSel =
  ## 2, [0, 2], {"all": true} or {"where": ["mass", ">", 1]} (ops: == != < <= > >=, "in" with an array).
  case j.kind
  of JInt: toRowSel(j.num.int)
  of JArray: toRowSel(conv(j, seq[int]))
  of JObject:
    if j.hasKey("all"): return allRows()
    let w = j{"where"}
    if w == nil or w.kind != JArray or w.len != 3: argError("rows are an index, [indices] or {\"where\": [column, op, value]}")
    let (col, op, val) = (conv(w[0], string), conv(w[1], string), w[2])
    let v = jsonValue(val)
    proc test(x: Value): bool =
      case op
      of "==": x == v
      of "!=": not (x == v)
      of "<": x < v
      of ">": v < x
      of "<=": x < v or x == v
      of ">=": v < x or x == v
      of "in": (var found = false; (for e in val.elems: (if x == jsonValue(e): found = true)); found)
      else: false
    if op notin ["==", "!=", "<", ">", "<=", ">=", "in"]: argError("unknown operator " & op)
    RowSel(kind: rsWhere, pred: proc (r: Row): bool = test(r[col]))
  else: argError("expected rows, got " & $j)

proc conv*(j: JsonNode, T: typedesc[CellStyle]): CellStyle =
  ## {"fill": "#fff3b0"}, {"text": {"weight": "bold", "color": "red"}}, {"css": "..."},
  ## {"borders": {"sides": ["top"], "color": "#000", "weight": "2px"}}, or an array of them.
  if j.kind == JArray:
    for e in j.elems: result = result & conv(e, CellStyle)
    return
  if j.kind != JObject: argError("expected a style, got " & $j)
  for k, v in j.fields:
    case norm(k)
    of "fill": result = result & style.fill(conv(v, string))
    of "css": result = result & style.css(conv(v, string))
    of "text":
      let g = proc (name: string): string = v{name}.getStr
      result = result & style.text(color = g("color"), font = g("font"), size = g("size"),
        align = g("align"), weight = g("weight"), style = g("style"))
    of "borders":
      var sides: set[Side]
      if v.hasKey("sides"):
        for s in v["sides"].elems: sides.incl conv(s, Side)
      else: sides = {sTop, sRight, sBottom, sLeft}
      result = result & style.borders(sides, color = v{"color"}.getStr("#000000"),
        weight = v{"weight"}.getStr("1px"))
    else: argError("unknown style " & k)

proc conv*(j: JsonNode, T: typedesc[Loc]): Loc =
  ## "title", "subtitle", "stubhead", "header", "columnHeader", "footer", "sourceNotes",
  ## "footnotes", or {"body": {"columns": ..., "rows": ...}}, {"columnLabels": cols},
  ## {"stub": {"rows": ...}}, {"rowGroups": [...]}, {"spanners": [...]}.
  let (key, v) = if j.kind == JString: (norm(j.str), newJNull())
                 elif j.kind == JObject and j.len == 1: (var p: (string, JsonNode); (for k, x in j.fields: p = (norm(k), x)); p)
                 else: argError("expected a location, got " & $j)
  let cols = if v.kind == JObject and v.hasKey("columns"): conv(v["columns"], ColSel)
             elif v.kind in {JString, JArray}: conv(v, ColSel) else: everything()
  let rows = if v.kind == JObject and v.hasKey("rows"): conv(v["rows"], RowSel) else: allRows()
  let names = if v.kind == JArray: conv(v, seq[string]) elif v.kind == JString: @[v.str] else: @[]
  case key
  of "title": loc.title
  of "subtitle": loc.subtitle
  of "stubhead": loc.stubhead
  of "header": loc.header
  of "columnheader": loc.columnHeader
  of "footer": loc.footer
  of "sourcenotes": loc.sourceNotes
  of "footnotes": loc.footnotes
  of "body": loc.body(cols, rows)
  of "columnlabels": loc.columnLabels(cols)
  of "stub": loc.stub(rows)
  of "rowgroups": loc.rowGroups(names)
  of "spanners", "spannerlabels": loc.spanners(names)
  else: argError("unknown location " & key)

proc conv*(j: JsonNode, T: typedesc[Aggregate]): Aggregate =
  ## "sum", "mean", "median", "std", "min", "max", "count".
  case norm(conv(j, string))
  of "sum": agg.sum
  of "mean": agg.mean
  of "median": agg.median
  of "std", "sd": agg.std
  of "min": agg.min
  of "max": agg.max
  of "count", "n": agg.count
  else: argError("unknown aggregate " & $j)

proc conv*[A, B](j: JsonNode, T: typedesc[seq[(A, B)]]): seq[(A, B)] =
  ## Pairs as a JSON object, in its order: {"mass": "Mass", "moons": "Moons"}.
  if j.kind == JObject:
    for k, v in j.fields: result.add (k, conv(v, B))
  elif j.kind == JArray:
    for e in j.elems:
      if e.kind != JArray or e.len != 2: argError("expected [key, value] pairs")
      result.add (conv(e[0], A), conv(e[1], B))
  else: argError("expected pairs, got " & $j)

proc conv*(j: JsonNode, T: typedesc[seq[string]]): seq[string] =
  ## A palette may be named: "blues" is `palette("blues")`; an array is the colours themselves.
  if j.kind == JString: return @[j.str]
  if j.kind != JArray: argError("expected an array of strings, got " & $j)
  for e in j.elems: result.add conv(e, string)

proc convPalette*(j: JsonNode): seq[string] =
  if j.kind == JString: palette(j.str) else: conv(j, seq[string])

# ------------------------------------------------------------------- the dispatch, from signatures

proc has*(a: Args, i: int, name: string): bool = i < a.pos.len or a.named.hasKey(norm(name))
proc get*(a: Args, i: int, name: string): JsonNode =
  if i < a.pos.len: a.pos[i] else: a.named[norm(name)]

proc fits*(a: Args, names, required: openArray[string]): bool =
  ## Whether `a` names only parameters of this form and gives all the required ones.
  if a.pos.len > names.len: return false
  for k in a.named.keys:
    var known = false
    for i, n in names:
      if norm(n) == k: (known = true; if i < a.pos.len: return false)
    if not known: return false
  for r in required:
    var given = a.named.hasKey(norm(r))
    for i, n in names:
      if n == r and i < a.pos.len: given = true
    if not given: return false
  true

proc seqType(n: NimNode): NimNode =
  ## The type a parameter is converted to: an openArray or varargs becomes a seq.
  let s = n.repr
  for wrap in ["openArray[", "varargs["]:
    if s.startsWith(wrap): return parseExpr("seq[" & s[wrap.len .. ^1])
  parseExpr(s)

proc defaultExpr(d: NimNode): NimNode =
  let s = d.repr
  if s.startsWith("["): parseExpr("@" & s) else: parseExpr(s)

macro verbsFromSignatures*(verbs: varargs[typed]): untyped =
  ## For every overload of every verb: a branch of `applyVerb` that converts the JSON arguments
  ## to its parameter types and calls it, kept only `when compiles` (all its types convert).
  let t = ident"t"
  let a = ident"a"
  let name = ident"name"
  let why = ident"why"
  var body = newStmtList()
  var known = nnkBracket.newTree()
  var forms = newStmtList()
  let fs = ident"fs"
  for v in verbs:
    let syms = if v.kind in {nnkClosedSymChoice, nnkOpenSymChoice}: toSeq(v.children) else: @[v]
    let vname = $syms[0]
    known.add newLit(vname)
    var branch = newStmtList()
    for s in syms:
      let impl = s.getImpl
      when defined(debugVerbs):
        if vname == "tabHeader": echo impl.kind, " generic=", impl[2].kind, " ", s.getTypeImpl.repr
      if impl.kind notin {nnkProcDef, nnkFuncDef} or impl[2].kind != nnkEmpty: continue  # generic
      let ty = s.getTypeImpl  # types filled in, also for `rows = allRows()`
      let fp = ty[0]
      let ip = impl[3]
      if fp.len < 2 or "Tabella" notin fp[1][^2].repr: continue
      var names, required: seq[string]
      var decls = newStmtList()
      var call = newCall(ident(vname), t)
      var probe = newCall(ident(vname), t)
      var idx = 0
      var dflts: seq[NimNode]
      for k in 1 ..< ip.len:  # defaults from the source
        for m in 0 ..< ip[k].len - 2: dflts.add ip[k][^1]
      for k in 2 ..< fp.len:
        let pname = $fp[k][0]
        let ptype = seqType(fp[k][1])
        let dflt = dflts[k - 1]
        names.add pname
        let pv = ident("p_" & pname)
        let conv = if ptype.repr == "seq[string]" and pname == "palette":
                     newCall(ident"convPalette", newCall(ident"get", a, newLit(idx), newLit(pname)))
                   else: newCall(ident"conv", newCall(ident"get", a, newLit(idx), newLit(pname)), ptype)
        if dflt.kind == nnkEmpty:
          required.add pname
          decls.add quote do:
            let `pv`: `ptype` = `conv`
        else:
          let d = defaultExpr(dflt)
          decls.add quote do:
            let `pv`: `ptype` = (if has(`a`, `idx`, `pname`): `conv` else: `d`)
        call.add newNimNode(nnkExprEqExpr).add(ident(pname), pv)
        probe.add newNimNode(nnkExprEqExpr).add(ident(pname), conv.copyNimTree)
        inc idx
      let namesLit = newLit(names)
      let reqLit = newLit(required)
      let vnameLit = newLit(vname)
      let probe2 = probe.copyNimTree
      forms.add quote do:
        block:
          let `a` = Args()
          var `t`: Tabella
          when compiles(`probe2`): `fs`.add (`vnameLit`, `namesLit`, `reqLit`, true)
          else: `fs`.add (`vnameLit`, `namesLit`, `reqLit`, false)
      branch.add quote do:
        when compiles(`probe`):
          if fits(`a`, `namesLit`, `reqLit`):
            var ok = false
            try:
              `decls`
              ok = true
              return `call`
            except ArgError as e:
              if ok: raise
              `why`.add "\n  (" & `namesLit`.join(", ") & "): " & e.msg
    let vn = newLit(norm(vname))
    when defined(debugVerbs):
      if vname == "tabHeader": echo branch.repr
    body.add quote do:
      if norm(`name`) == `vn`:
        `branch`
        raise newException(ArgError, "no form of " & `name` & " takes " & $`a`.pos & " " &
          $`a`.named.keys.toSeq & `why`)
  let vnames = postfix(ident"verbNames", "*")
  let apply = postfix(ident"applyVerb", "*")
  let vforms = postfix(ident"verbForms", "*")
  result = quote do:
    proc `vforms`(): seq[(string, seq[string], seq[string], bool)] =
      ## Every overload of every verb: its name, parameters, required ones, and whether it takes JSON.
      var `fs`: seq[(string, seq[string], seq[string], bool)]
      `forms`
      `fs`
    const `vnames` = `known`
    proc `apply`(`t`: sink Tabella, `name`: string, `a`: Args): Tabella =
      var `why` = ""
      `body`
      raise newException(ArgError, "unknown verb " & `name`)


verbsFromSignatures(
  tabHeader, tabStubhead, tabSpanner, tabSpannerDelim, tabCaption, tabSourceNote, tabRowGroup,
  tabFootnote, tabStyle, tabStubIndent,
  rmHeader, rmStubhead, rmCaption, rmSpanners, rmFootnotes, rmSourceNotes,
  colsLabel, colsAlign, colsWidth, colsHide, colsUnhide, colsMove, colsMoveToStart, colsMoveToEnd,
  colsReorder, colsUnits, colsMerge, colsMergeRange, colsMergeUncert, colsMergeNPct, colsAlignDecimal,
  colsNanoplot,
  rowOrder, rowGroupOrder, rowsHide, rowsUnhide,
  textReplace, textCaseMatch,
  fmtNumber, fmtInteger, fmtPercent, fmtCurrency, fmtScientific, fmtEngineering, fmtNumberSi,
  fmtRoman, fmtDate, fmtTime, fmtDatetime, fmtDuration, fmtMarkdown, fmtPartsper, fmtBytes, fmtIndex,
  fmtSpelledNum, fmtUrl, fmtEmail, fmtFlag, fmtTf, fmtFraction, fmtBins, fmtPassthrough, fmtCountry,
  fmtAuto, fmtUnits, fmtChem, fmtIcon, fmtImage, fmtNanoplot,
  subMissing, subZero, subSmallVals, subLargeVals, subValues,
  summaryRows, grandSummaryRows, summaryColumns,
  dataColor,
  optRowStriping, optAlignTableHeader, optAllCaps, optTableFont, optTableLines, optTableOutline,
  optHorizontalPadding, optVerticalPadding, optStylize, optFootnoteMarks, optFootnoteOrder,
  optFootnoteSpec, optCssTheme, optCss)
