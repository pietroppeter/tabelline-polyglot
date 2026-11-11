%% tabelline for Erlang: a table is a map, the way the JSON spec has it, rendered by the NIF.
%%
%%   T = tabelline:new(#{planet => [<<"Mercury">>, <<"Venus">>], mass => [0.33, 4.87]},
%%                     #{rownameCol => <<"planet">>}),
%%   T2 = tabelline:verb(T, fmtNumber, #{columns => <<"mass">>, decimals => 2}),
%%   {ok, Html} = tabelline:render(T2, html).
%%
%% Uses OTP 27's json module to write the spec.
-module(tabelline).
-export([new/2, verb/3, render/2, md/1]).

new(Columns, Settings) when is_list(Columns); is_map(Columns) ->
    Settings#{data => #{columns => {ordered, Columns}}, verbs => []}.

%% Args: a list (positional) or a map (named); keys and the verb name may be atoms.
verb(T = #{verbs := Vs}, Name, Args) -> T#{verbs := Vs ++ [#{Name => Args}]}.

md(S) -> #{md => S}.

render(T, Format) ->
    tabelline_nif:render_spec(json:encode(T, fun encode/2), atom_to_binary(Format)).

%% Columns keep their order: {ordered, [{Name, Values}]}.
encode({ordered, KVs}, Enc) when is_list(KVs) -> json:encode_key_value_list(KVs, Enc);
encode({ordered, M}, Enc) when is_map(M) -> json:encode_map(M, Enc);
encode(T, Enc) when is_tuple(T) -> json:encode_list(tuple_to_list(T), Enc);
encode(V, Enc) -> json:encode_value(V, Enc).
