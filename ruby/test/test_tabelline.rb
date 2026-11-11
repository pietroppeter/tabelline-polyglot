require "minitest/autorun"
require_relative "../lib/tabelline"

class TestTabelline < Minitest::Test
  FRUITS = [{ fruit: "apple", price: 1.5, stock: 10 }, { fruit: "kiwi", price: 0.25, stock: nil }].freeze

  def test_any_verb_is_a_method
    table = Tabelline.table(FRUITS) do
      fmt_currency :price, currency: "EUR"
      sub_missing :stock, missing_text: "sold out"
    end
    assert_equal "| fruit | price | stock |\n|:--|--:|--:|\n| apple | €1.50 | 10 |\n| kiwi | €0.25 | sold out |",
                 table.to_markdown
  end

  def test_a_verb_on_a_missing_column_raises
    table = Tabelline.table(FRUITS) { fmt_integer :weight }
    error = assert_raises(Tabelline::Error) { table.to_html }
    assert_match(/weight/, error.message)
  end
end
