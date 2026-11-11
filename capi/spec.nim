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

import std/json
import tabelline, tabelline/datasets
import verbs_json

proc dataFromJson*(j: JsonNode): TableData =
  ## {"columns": {"name": [values], ...}}, {"csv": "text"} or {"dataset": "planets"}.
  if j.hasKey("csv"): return parseCsv(j["csv"].getStr)
  if j.hasKey("dataset"):
    case j["dataset"].getStr
    of "planets": return planets()
    of "gtcars": return gtcars()
    of "countrypops": return countrypops()
    of "illness": return illness()
    of "metro": return metro()
    else: raise newException(ValueError, "unknown dataset " & j["dataset"].getStr)
  var cols: seq[(string, seq[Value])]
  for name, vs in j["columns"].pairs:
    var values: seq[Value]
    for v in vs.elems: values.add jsonValue(v)
    cols.add (name, values)
  toTableData(cols)

proc tabellaFromSpec*(spec: JsonNode): Tabella =
  ## {"data": ..., "rownameCol": "planet", "groupnameCol": "type", "locale": "it",
  ##  "verbs": [{"tabHeader": ["The planets"]}, {"fmtNumber": {"columns": "mass", "decimals": 3}}]}
  result = initTabella(dataFromJson(spec["data"]), rownameCol = spec{"rownameCol"}.getStr,
    groupnameCol = spec{"groupnameCol"}.getStr, id = spec{"id"}.getStr, locale = spec{"locale"}.getStr)
  for v in spec{"verbs"}.getElems:
    for name, args in v.pairs:
      result = result.applyVerb(name, toArgs(args))

