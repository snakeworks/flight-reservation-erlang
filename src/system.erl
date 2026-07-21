-module(system).
-include("base.hrl").
-export([init/0, add_flight/1, reserve/1, stop/0, flight_get/1]).

-define(TABLE, flights).

init() ->
    ?TABLE = ets:new(?TABLE, [bag, public, named_table, {read_concurrency, true}]),
    ok.

add_flight(Flight = #flight{from = From, to = To}) ->
    Pid = flight_start(Flight),
    true = ets:insert(?TABLE, {{From, To}, Pid}),
    Pid.

reserve(Customer = #customer{from = From, to = To}) ->
    route_reserve(lookup(From, To), Customer).

stop() ->
    ets:delete(?TABLE),
    ok.

route_reserve([], _Customer) ->
    {error, no_availability};
route_reserve([Pid | Rest], Customer) ->
    case flight_reserve(Pid, Customer) of
        {ok, FlightId, Cost} ->
            {ok, FlightId, Cost};
        {error, _Reason} ->
            route_reserve(Rest, Customer)
    end.

lookup(From, To) ->
    [Pid || {_Route, Pid} <- ets:lookup(?TABLE, {From, To})].

flight_start(Flight = #flight{}) ->
    spawn(fun() -> flight_loop(Flight) end).

flight_reserve(Pid, Customer = #customer{}) ->
    flight_call(Pid, {reserve, Customer}).

flight_get(Pid) ->
    flight_call(Pid, get).

flight_call(Pid, Request) ->
    Ref = make_ref(),
    Pid ! {Request, self(), Ref},
    receive
        {Ref, Reply} -> Reply
    end.

flight_loop(Flight = #flight{id = Id}) ->
    receive
        {{reserve, Customer}, From, Ref} ->
            case booking:reserve(Flight, Customer) of
                {ok, Updated, Cost} ->
                    From ! {Ref, {ok, Id, Cost}},
                    flight_loop(Updated);
                {error, Reason} ->
                    From ! {Ref, {error, Reason}},
                    flight_loop(Flight)
            end;
        {get, From, Ref} ->
            From ! {Ref, Flight},
            flight_loop(Flight);
        stop ->
            ok
    end.
