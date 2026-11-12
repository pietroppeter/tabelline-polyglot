-module(tabelline_test_ffi).
-export([contains/2]).

contains(Haystack, Needle) -> binary:match(Haystack, Needle) =/= nomatch.
