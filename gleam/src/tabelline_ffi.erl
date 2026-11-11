%% The few Erlang functions the Gleam modules use, instead of gleam_stdlib and gleam_json:
%% tabelline has no dependencies, so it builds where Hex cannot be reached.
-module(tabelline_ffi).
-export([json_string/1, json_number/1, render/2, print/1, arguments/0]).

json_string(S) -> iolist_to_binary(json:encode(S)).
json_number(N) -> iolist_to_binary(json:encode(N)).

render(Spec, Format) ->
    case tabelline_nif:render_spec(Spec, Format) of
        {ok, Out} -> {ok, Out};
        {error, Why} -> {error, Why}
    end.

%% S is UTF-8: written as characters on a unicode device (gleam run), as bytes otherwise (erl -noshell).
print(S) ->
    case proplists:get_value(encoding, io:getopts(standard_io), latin1) of
        unicode -> io:put_chars(standard_io, S);
        _ -> file:write(standard_io, S)
    end,
    nil.

arguments() -> [unicode:characters_to_binary(A) || A <- init:get_plain_arguments()].
