-module(planets).
-export([main/0]).

main() ->
    T0 = tabelline:new(
        [{planet, [<<"Mercury">>, <<"Venus">>, <<"Earth">>, <<"Mars">>, <<"Jupiter">>, <<"Saturn">>, <<"Uranus">>, <<"Neptune">>]},
         {type, [<<"Terrestrial">>, <<"Terrestrial">>, <<"Terrestrial">>, <<"Terrestrial">>,
                 <<"Gas giant">>, <<"Gas giant">>, <<"Ice giant">>, <<"Ice giant">>]},
         {diameter, [4879, 12104, 12756, 6792, 142984, 120536, 51118, 49528]},
         {mass, [0.33, 4.87, 5.97, 0.642, 1898.0, 568.0, 86.8, 102.0]},
         {distance, [57.9, 108.2, 149.6, 228.0, 778.5, 1432.0, 2867.0, 4515.0]},
         {moons, [0, 0, 1, 2, 95, 146, 28, 16]}],
        #{rownameCol => <<"planet">>, groupnameCol => <<"type">>, id => <<"planets">>}),
    Verbs = [
        {tabHeader, [<<"The planets">>, tabelline:md(<<"of the *Solar System*">>)]},
        {tabSpanner, [<<"Size">>, [<<"diameter">>, <<"mass">>]]},
        {colsLabel, #{labels => {ordered, [{diameter, <<"Diameter (km)"/utf8>>}, {mass, <<"Mass (10²⁴ kg)"/utf8>>},
                                           {distance, <<"From the Sun (10⁶ km)"/utf8>>}, {moons, <<"Moons">>}]}}},
        {fmtInteger, [<<"diameter">>]},
        {fmtNumber, #{columns => <<"mass">>, decimals => 2}},
        {fmtNumber, #{columns => <<"distance">>, decimals => 1}},
        {dataColor, #{columns => <<"moons">>, palette => <<"blues">>}},
        {tabStyle, [#{text => #{weight => <<"bold">>}},
                    [#{body => #{columns => <<"moons">>, rows => #{where => [<<"moons">>, <<">">>, 50]}}}]]},
        {tabFootnote, [<<"Moons confirmed by 2025.">>, [#{columnLabels => <<"moons">>}]]},
        {tabSourceNote, [<<"NASA, Planetary Fact Sheet">>]}],
    T = lists:foldl(fun({Name, Args}, Acc) -> tabelline:verb(Acc, Name, Args) end, T0, Verbs),
    {ok, Html} = tabelline:render(T, html),
    ok = file:write(standard_io, Html).
