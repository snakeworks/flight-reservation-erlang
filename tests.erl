-module(tests).
-include_lib("eunit/include/eunit.hrl").
-include("base.hrl").

spec_flight() ->
    base:flight(0, "BRU", "ATL", "Delta",
                [base:tier(600, 150, 0),
                 base:tier(650, 50, 0),
                 base:tier(700, 50, 0)]).

reserve_spec_example_test() ->
    C = base:customer(0, "BRU", "ATL", 5, 600),
    {ok, Flight, Cost} = booking:reserve(spec_flight(), C),
    ?assertEqual(3000, Cost),
    ?assertEqual([{tier, 600, 145, 5},
                  {tier, 650, 50, 0},
                  {tier, 700, 50, 0}], Flight#flight.pricing).

reserve_spans_tiers_test() ->
    C = base:customer(1, "BRU", "ATL", 160, 650),
    {ok, Flight, Cost} = booking:reserve(spec_flight(), C),
    ?assertEqual(150 * 600 + 10 * 650, Cost),
    ?assertEqual([{tier, 600, 0, 150},
                  {tier, 650, 40, 10},
                  {tier, 700, 50, 0}], Flight#flight.pricing).

reserve_below_budget_test() ->
    C = base:customer(2, "BRU", "ATL", 1, 500),
    ?assertEqual({error, not_enough_seats}, booking:reserve(spec_flight(), C)).

reserve_not_enough_seats_test() ->
    C = base:customer(3, "BRU", "ATL", 200, 600),
    ?assertEqual({error, not_enough_seats}, booking:reserve(spec_flight(), C)).

reserve_route_mismatch_test() ->
    C = base:customer(4, "BRU", "LAX", 1, 700),
    ?assertEqual({error, route_mismatch}, booking:reserve(spec_flight(), C)).

reserve_exact_tier_boundary_test() ->
    C = base:customer(5, "BRU", "ATL", 150, 600),
    {ok, Flight, _} = booking:reserve(spec_flight(), C),
    ?assertEqual({tier, 600, 0, 150}, hd(Flight#flight.pricing)).

reserve_route_spills_test() ->
    F0 = base:flight(0, "BRU", "ATL", "Delta",  [base:tier(600, 3, 0)]),
    F1 = base:flight(1, "BRU", "ATL", "United", [base:tier(620, 50, 0)]),
    C = base:customer(6, "BRU", "ATL", 5, 650),
    {ok, Flight, Cost} = booking:reserve_route([F0, F1], C),
    ?assertEqual(1, Flight#flight.id),
    ?assertEqual(5 * 620, Cost).

reserve_route_none_test() ->
    F0 = base:flight(0, "BRU", "ATL", "Delta", [base:tier(600, 3, 0)]),
    C = base:customer(7, "BRU", "ATL", 5, 600),
    ?assertEqual({error, no_availability}, booking:reserve_route([F0], C)).

reserve_route_empty_test() ->
    C = base:customer(8, "BRU", "ATL", 1, 600),
    ?assertEqual({error, no_availability}, booking:reserve_route([], C)).

flight_normalizes_pricing_test() ->
    F = base:flight(0, "BRU", "ATL", "Delta",
                    [base:tier(700, 50, 0),
                     base:tier(600, 150, 0),
                     base:tier(650, 50, 0)]),
    Prices = [P || #tier{price = P} <- F#flight.pricing],
    ?assertEqual([600, 650, 700], Prices).


