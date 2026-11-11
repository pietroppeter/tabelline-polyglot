%% The few Erlang functions the Gleam modules use (instead of gleam_stdlib and gleam_json).
-module(tabelline_ffi).
-export([json_string/1, json_number/1, render/2, print/1]).

json_string(S) -> iolist_to_binary(json:encode(S)).
json_number(N) -> iolist_to_binary(json:encode(N)).

render(Spec, Format) ->
    case tabelline_nif:render_spec(Spec, Format) of
        {ok, Out} -> {ok, Out};
        {error, Why} -> {error, Why}
    end.

print(S) -> file:write(standard_io, S), nil.
