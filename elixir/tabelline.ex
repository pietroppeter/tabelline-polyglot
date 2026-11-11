defmodule Tabelline do
  @moduledoc """
  Great tables for Elixir: tabelline (Nim) on the BEAM, through the same NIF as Erlang and
  Gleam (`:tabelline_nif`). A table is a map shaped like the JSON spec; verbs are added with
  pipes, and `render/2` hands it to the NIF in one call.

      Tabelline.new(planet: ["Mercury", "Venus"], mass: [0.33, 4.87])
      |> Tabelline.set(rownameCol: "planet")
      |> Tabelline.verb(:tab_header, ["The planets", Tabelline.md("of the *Solar System*")])
      |> Tabelline.verb(:fmt_number, columns: "mass", decimals: 2)
      |> Tabelline.render(:html)

  Names may be written the Elixir way (`:fmt_number`, `column_labels:`): the library ignores case
  and underscores. Keyword lists keep their order, so they are written as JSON objects.
  """

  def new(columns), do: %{data: %{columns: columns}, verbs: []}

  def set(t, settings), do: Enum.into(settings, t)

  def verb(t, name, args \\ []), do: %{t | verbs: t.verbs ++ [[{name, args}]]}

  def md(s), do: [md: s]

  def render(t, format \\ :html) do
    t |> encode() |> IO.iodata_to_binary() |> :tabelline_nif.render_spec(Atom.to_string(format))
  end

  def render!(t, format \\ :html) do
    case render(t, format) do
      {:ok, out} -> out
      {:error, why} -> raise "tabelline: " <> why
    end
  end

  # A keyword list is an object (in order), any other list an array.
  defp encode(m) when is_map(m), do: encode(Enum.to_list(m))
  defp encode([{k, _} | _] = kv) when is_atom(k), do: :json.encode(kv, &encoder/2)
  defp encode(v), do: :json.encode(v, &encoder/2)

  defp encoder([{k, _} | _] = kv, enc) when is_atom(k), do: :json.encode_key_value_list(kv, enc)
  defp encoder(m, enc) when is_map(m), do: :json.encode_key_value_list(Enum.to_list(m), enc)
  defp encoder(v, enc), do: :json.encode_value(v, enc)
end
