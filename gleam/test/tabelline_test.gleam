//// Tests with no test library: `gleam test` runs `main`, and a failing `assert` stops it with
//// the expression that failed. The NIF must be built first (`tools/polyglot.nim gleam`).
////

import tabelline.{DuplicateColumn, Exibble, Markdown, Plain, Rejected}
import tabelline/column
import tabelline/format

type Fruit {
  Fruit(name: String, price: Float, stock: Result(Int, Nil))
}

fn fruits() {
  [Fruit("apple", 1.5, Ok(10)), Fruit("kiwi", 0.25, Error(Nil))]
  |> tabelline.from_list
  |> column.string("fruit", fn(fruit) { fruit.name })
  |> column.float("price", fn(fruit) { fruit.price })
  |> column.int_or_missing("stock", fn(fruit) { fruit.stock })
}

pub fn main() {
  the_spec_lists_columns_in_order_and_steps_after_the_header()
  a_table_draws_as_markdown()
  two_columns_with_one_name_are_an_error()
  a_step_on_a_missing_column_is_rejected()
  a_dataset_draws_as_a_preview()
  a_whole_float_stays_a_float()
}

fn the_spec_lists_columns_in_order_and_steps_after_the_header() {
  let spec =
    fruits()
    |> tabelline.stub("fruit")
    |> tabelline.format(["price"], with: format.number(decimals: 2))
    |> tabelline.title(Plain("Fruit"))
    |> tabelline.subtitle(Markdown("*fresh*"))
    |> tabelline.to_json
  assert spec
    == "{\"data\":{\"columns\":{\"fruit\":[\"apple\",\"kiwi\"],\"price\":[1.5,0.25],\"stock\":[10,null]}},"
    <> "\"verbs\":[{\"tabHeader\":{\"title\":\"Fruit\",\"subtitle\":{\"md\":\"*fresh*\"}}},"
    <> "{\"fmtNumber\":{\"columns\":[\"price\"],\"rows\":{\"all\":true},\"decimals\":2}}],"
    <> "\"rownameCol\":\"fruit\"}"
}

fn a_table_draws_as_markdown() {
  let assert Ok(markdown) =
    fruits()
    |> tabelline.format(["price"], with: format.currency("EUR"))
    |> tabelline.missing(["stock"], show: "sold out")
    |> tabelline.to_markdown
  assert markdown
    == "| fruit | price | stock |\n|:--|--:|--:|\n| apple | €1.50 | 10 |\n| kiwi | €0.25 | sold out |"
}

fn two_columns_with_one_name_are_an_error() {
  let table =
    fruits()
    |> column.string("fruit", fn(fruit) { fruit.name })
  assert tabelline.to_html(table) == Error(DuplicateColumn(name: "fruit"))
}

fn a_step_on_a_missing_column_is_rejected() {
  let assert Error(Rejected(_)) =
    fruits()
    |> tabelline.format(["weight"], with: format.integer())
    |> tabelline.to_html
  Nil
}

fn a_dataset_draws_as_a_preview() {
  let table =
    tabelline.from_dataset(Exibble)
    |> tabelline.preview(top: 2, bottom: 1)
  assert tabelline.to_json(table)
    == "{\"data\":{\"dataset\":\"exibble\"},\"verbs\":[],\"preview\":{\"topN\":2,\"bottomN\":1}}"
  let assert Ok(markdown) = tabelline.to_markdown(table)
  assert contains(markdown, "| 3..7 |")
}

// On JavaScript a Float is a number, and 2.0 is 2: the spec must still say 2.0.
fn a_whole_float_stays_a_float() {
  let spec =
    [Fruit("melon", 2.0, Ok(1))]
    |> tabelline.from_list
    |> column.float("price", fn(fruit) { fruit.price })
    |> tabelline.to_json
  assert spec == "{\"data\":{\"columns\":{\"price\":[2.0]}},\"verbs\":[]}"
}

@external(erlang, "tabelline_test_ffi", "contains")
@external(javascript, "./tabelline_test_ffi.mjs", "contains")
fn contains(haystack: String, needle: String) -> Bool
