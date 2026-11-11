//// Tests with no test library: `gleam test` runs `main`, and a failing `assert` stops it with
//// the expression that failed. The NIF must be built first (`tools/polyglot.nim gleam`).
////

import tabelline.{DuplicateColumn, Markdown, Plain, Rejected}
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
