%% tabelline on the BEAM: the NIF over libtabelline (c_src/tabelline_nif.c).
%% render_spec(Spec, Format) -> {ok, Binary} | {error, Binary}; Spec is the table as JSON iodata.
-module(tabelline_nif).
-export([render_spec/2, version/0]).
-on_load(init/0).

init() ->
    Dir = case os:getenv("TABELLINE_NIF_DIR") of
              false -> filename:join(filename:dirname(code:which(?MODULE)), "../priv");
              D -> D
          end,
    erlang:load_nif(filename:join(Dir, "tabelline_nif"), 0).

render_spec(_Spec, _Format) -> erlang:nif_error(not_loaded).
version() -> erlang:nif_error(not_loaded).
