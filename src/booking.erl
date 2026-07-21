-module(booking).
-include("base.hrl").
-export([matches/2, reserve/2, reserve_route/2]).

matches(#flight{from = From, to = To}, #customer{from = From, to = To}) ->
    true;
matches(#flight{}, #customer{}) ->
    false.

reserve(Flight = #flight{pricing = Pricing}, Customer = #customer{seats = Seats, budget = Budget}) ->
    case matches(Flight, Customer) of
        false ->
            {error, route_mismatch};
        true ->
            case consume(Pricing, Budget, Seats, [], 0) of
                {ok, NewPricing, Cost} ->
                    {ok, Flight#flight{pricing = NewPricing}, Cost};
                error ->
                    {error, not_enough_seats}
            end
    end.

reserve_route([], _Customer) ->
    {error, no_availability};
reserve_route([Flight | Rest], Customer) ->
    case reserve(Flight, Customer) of
        {ok, UpdatedFlight, Cost} ->
            {ok, UpdatedFlight, Cost};
        {error, _Reason} ->
            reserve_route(Rest, Customer)
    end.

consume(Tiers, _Budget, 0, Done, Cost) ->
    {ok, lists:reverse(Done, Tiers), Cost};
consume([], _Budget, _Remaining, _Done, _Cost) ->
    error; % No more seats in budget
consume([Tier = #tier{price = P} | Rest], Budget, Remaining, Done, Cost)
  when P > Budget ->
    consume(Rest, Budget, Remaining, [Tier | Done], Cost); % unreachable seats
consume([Tier = #tier{price = P, available = A, occupied = O} | Rest],
        Budget, Remaining, Done, Cost) ->
    ToTake = min(A, Remaining),
    Moved = Tier#tier{available = A - ToTake, occupied = O + ToTake},
    consume(Rest, Budget, Remaining - ToTake, [Moved | Done], Cost + ToTake * P).
