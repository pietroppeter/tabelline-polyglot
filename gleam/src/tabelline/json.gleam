//// JSON values, just enough to write a table's spec (the shape of gleam_json's API, which the
//// sandbox could not download).

pub opaque type Json {
  Json(text: String)
}

@external(erlang, "tabelline_ffi", "json_string")
fn encode_string(s: String) -> String

@external(erlang, "tabelline_ffi", "json_number")
fn encode_int(i: Int) -> String

@external(erlang, "tabelline_ffi", "json_number")
fn encode_float(f: Float) -> String

pub fn string(s: String) -> Json {
  Json(encode_string(s))
}

pub fn int(i: Int) -> Json {
  Json(encode_int(i))
}

pub fn float(f: Float) -> Json {
  Json(encode_float(f))
}

pub fn bool(b: Bool) -> Json {
  case b {
    True -> Json("true")
    False -> Json("false")
  }
}

pub fn null() -> Json {
  Json("null")
}

pub fn preprocessed_array(items: List(Json)) -> Json {
  Json("[" <> join(items, fn(j) { j.text }) <> "]")
}

pub fn array(items: List(a), of f: fn(a) -> Json) -> Json {
  preprocessed_array(map(items, f))
}

pub fn object(fields: List(#(String, Json))) -> Json {
  Json(
    "{"
    <> join(fields, fn(kv) { encode_string(kv.0) <> ":" <> { kv.1 }.text })
    <> "}",
  )
}

pub fn to_string(j: Json) -> String {
  j.text
}

pub fn map(xs: List(a), f: fn(a) -> b) -> List(b) {
  case xs {
    [] -> []
    [x, ..rest] -> [f(x), ..map(rest, f)]
  }
}

fn join(xs: List(a), f: fn(a) -> String) -> String {
  case xs {
    [] -> ""
    [x] -> f(x)
    [x, ..rest] -> f(x) <> "," <> join(rest, f)
  }
}
