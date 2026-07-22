-module(tests).
-include_lib("eunit/include/eunit.hrl").
-include("base.hrl").

test_flight() ->
    base:flight(0, "BRU", "ATL", "Ryanair",
                [base:tier(600, 150, 0),
                 base:tier(650, 50, 0),
                 base:tier(700, 50, 0)]).

reserve_spec_example_test() ->
    C = base:customer(0, "BRU", "ATL", 5, 600),
    {ok, Flight, Cost} = booking:reserve(test_flight(), C),
    ?assertEqual(3000, Cost),
    ?assertEqual([{tier, 600, 145, 5},
                  {tier, 650, 50, 0},
                  {tier, 700, 50, 0}], Flight#flight.pricing).

reserve_spans_tiers_test() ->
    C = base:customer(1, "BRU", "ATL", 160, 650),
    {ok, Flight, Cost} = booking:reserve(test_flight(), C),
    ?assertEqual(150 * 600 + 10 * 650, Cost),
    ?assertEqual([{tier, 600, 0, 150},
                  {tier, 650, 40, 10},
                  {tier, 700, 50, 0}], Flight#flight.pricing).

reserve_below_budget_test() ->
    C = base:customer(2, "BRU", "ATL", 1, 500),
    ?assertEqual({error, not_enough_seats}, booking:reserve(test_flight(), C)).

reserve_not_enough_seats_test() ->
    C = base:customer(3, "BRU", "ATL", 200, 600),
    ?assertEqual({error, not_enough_seats}, booking:reserve(test_flight(), C)).

reserve_route_mismatch_test() ->
    C = base:customer(4, "BRU", "ZAG", 1, 700),
    ?assertEqual({error, route_mismatch}, booking:reserve(test_flight(), C)).

reserve_exact_tier_boundary_test() ->
    C = base:customer(5, "BRU", "ATL", 150, 600),
    {ok, Flight, _} = booking:reserve(test_flight(), C),
    ?assertEqual({tier, 600, 0, 150}, hd(Flight#flight.pricing)).

reserve_route_spills_test() ->
    F0 = base:flight(0, "BRU", "ATL", "Ryanair",  [base:tier(600, 3, 0)]),
    F1 = base:flight(1, "BRU", "ATL", "Delta", [base:tier(620, 50, 0)]),
    C = base:customer(6, "BRU", "ATL", 5, 650),
    {ok, Flight, Cost} = booking:reserve_route([F0, F1], C),
    ?assertEqual(1, Flight#flight.id),
    ?assertEqual(5 * 620, Cost).

reserve_route_none_test() ->
    F0 = base:flight(0, "BRU", "ATL", "Ryanair", [base:tier(600, 3, 0)]),
    C = base:customer(7, "BRU", "ATL", 5, 600),
    ?assertEqual({error, no_availability}, booking:reserve_route([F0], C)).

reserve_route_empty_test() ->
    C = base:customer(8, "BRU", "ATL", 1, 600),
    ?assertEqual({error, no_availability}, booking:reserve_route([], C)).

flight_normalizes_pricing_test() ->
    F = base:flight(0, "BRU", "ATL", "Ryanair",
                    [base:tier(700, 50, 0),
                     base:tier(600, 150, 0),
                     base:tier(650, 50, 0)]),
    Prices = [P || #tier{price = P} <- F#flight.pricing],
    ?assertEqual([600, 650, 700], Prices).

setup() -> system:init().
cleanup(_) -> system:stop().

no_overbooking_test_() ->
    {setup, fun setup/0, fun cleanup/1,
    fun(_) ->
        fun() ->
            P0 = system:add_flight(base:flight(0, "BRU", "ATL", "Ryanair",
                                            [base:tier(600, 3, 0)])),
            P1 = system:add_flight(base:flight(1, "BRU", "ATL", "Delta",
                                            [base:tier(620, 50, 0)])),
            Results = swarm(200, fun(I) ->
                                base:customer(I, "BRU", "ATL", 1, 650)
                                end),
            Successes = length([1 || {ok, _, _} <- Results]),
            Booked = occupied(system:flight_get(P0))
                    + occupied(system:flight_get(P1)),
            ?assertEqual(53, Successes),
            ?assertEqual(53, Booked),
            ?assert(occupied(system:flight_get(P0)) =< 3),
            ?assert(occupied(system:flight_get(P1)) =< 50)
        end
    end}.

reserve_facade_test_() ->
    {setup, fun setup/0, fun cleanup/1,
    fun(_) ->
        fun() ->
            system:add_flight(base:flight(0, "BRU", "ATL", "Ryanair",
                                        [base:tier(600, 10, 0)])),
            ?assertMatch({ok, 0, 3000},
                        system:reserve(base:customer(1, "BRU", "ATL", 5, 600)))
        end
    end}.

reserve_unknown_route_test_() ->
    {setup, fun setup/0, fun cleanup/1,
    fun(_) ->
        fun() ->
            ?assertEqual({error, no_availability},
                    system:reserve(base:customer(1, "BRU", "RJK", 1, 600)))
        end
    end}.

single_booking_no_partial_test_() ->
    {setup, fun setup/0, fun cleanup/1,
    fun(_) ->
        fun() ->
            P0 = system:add_flight(base:flight(0, "BRU", "ATL", "Ryanair",
                                            [base:tier(600, 3, 0)])),
            P1 = system:add_flight(base:flight(1, "BRU", "ATL", "Delta",
                                            [base:tier(620, 50, 0)])),
            {ok, Id, _} = system:reserve(base:customer(1, "BRU", "ATL", 5, 650)),
            ?assertEqual(1, Id),
            ?assertEqual(0, occupied(system:flight_get(P0))),
            ?assertEqual(5, occupied(system:flight_get(P1)))
        end
    end}.

%% Helpers

swarm(N, MakeCustomer) ->
    Parent = self(),
    [spawn(fun() -> Parent ! {result, system:reserve(MakeCustomer(I))} end) || I <- lists:seq(1, N)],
    [receive {result, R} -> R end || _ <- lists:seq(1, N)].

occupied(#flight{pricing = Pricing}) ->
    lists:sum([O || #tier{occupied = O} <- Pricing]).
