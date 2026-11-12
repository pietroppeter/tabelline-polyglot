## The JSON spec of a table: what `tbl_render_spec` reads (layer 1 of libtabelline).
##
## ```json
## {"data": {"columns": {"planet": ["Mercury", "Venus"], "mass": [0.33, 4.87]}},
##  "rownameCol": "planet", "groupnameCol": "", "id": "planets", "locale": "",
##  "verbs": [{"tabHeader": ["The planets", {"md": "of the *Solar System*"}]},
##            {"fmtNumber": {"columns": "mass", "decimals": 2}}]}
## ```
##
## `data` is columns (in order), `{"csv": "..."}` or `{"dataset": "planets"}`. Each verb is an
## object with one key, its name; the value is its arguments (`verbs_json.toArgs`).
## `"preview": {"topN": 5, "bottomN": 1, "inclRownums": true}` draws the first and the last rows
## only, as `initTabellaPreview` (gt's `gt_preview()`); the stub is then the row numbers.

import std/[json, tables]
import tabelline, tabelline/datasets
import verbs_json

var datasetCache: Table[string, TableData]

proc dataFromJson*(j: JsonNode): TableData =
  ## {"columns": {"name": [values], ...}}, {"csv": "text"} or {"dataset": "planets"}.
  if j.hasKey("csv"): return parseCsv(j["csv"].getStr)
  if j.hasKey("dataset"):
    # read once, then kept: a TableData is only read, and countrypops takes 200 ms to parse in JavaScript
    let name = j["dataset"].getStr
    {.cast(gcsafe).}:
      if name notin datasetCache:
        datasetCache[name] = case name
          of "planets": planets()
          of "exibble": exibble()
          of "isole": isole()
          of "citta": citta()
          of "gtcars": gtcars()
          of "countrypops": countrypops()
          of "illness": illness()
          of "metro": metro()
          else: raise newException(ValueError, "unknown dataset " & name)
      return datasetCache[name]
  var cols: seq[(string, seq[Value])]
  for name, vs in j["columns"].pairs:
    var values: seq[Value]
    for v in vs.elems: values.add jsonValue(v)
    cols.add (name, values)
  toTableData(cols)

proc tabellaFromSpec*(spec: JsonNode): Tabella =
  ## {"data": ..., "rownameCol": "planet", "groupnameCol": "type", "locale": "it",
  ##  "verbs": [{"tabHeader": ["The planets"]}, {"fmtNumber": {"columns": "mass", "decimals": 3}}]}
  let data = dataFromJson(spec["data"])
  if spec.hasKey("preview"):
    let p = spec["preview"]
    result = initTabellaPreview(data, topN = p{"topN"}.getInt(5), bottomN = p{"bottomN"}.getInt(1),
                                inclRownums = p{"inclRownums"}.getBool(true))
    result.id = spec{"id"}.getStr
    result.locale = spec{"locale"}.getStr
  else:
    result = initTabella(data, rownameCol = spec{"rownameCol"}.getStr,
      groupnameCol = spec{"groupnameCol"}.getStr, id = spec{"id"}.getStr, locale = spec{"locale"}.getStr)
  for v in spec{"verbs"}.getElems:
    for name, args in v.pairs:
      result = result.applyVerb(name, toArgs(args))

