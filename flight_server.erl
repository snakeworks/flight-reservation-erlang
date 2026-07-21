-module(flight_server).
-include("base.hrl").
-export([start/1, reserve/2, get/1, stop/1]).

start(Flight = #flight{}) ->
    spawn(fun() -> loop(Flight) end).

reserve(Pid, Customer = #customer{}) ->
    call(Pid, {reserve, Customer}).

get(Pid) ->
    call(Pid, get).

stop(Pid) ->
    Pid ! stop,
    ok.

call(Pid, Request) ->
    Ref = make_ref(),
    Pid ! {Request, self(), Ref},
    receive
        {Ref, Reply} -> Reply
    end.

loop(Flight = #flight{id = Id}) ->
    receive
        {{reserve, Customer}, From, Ref} ->
            case booking:reserve(Flight, Customer) of
                {ok, Updated, Cost} ->
                    From ! {Ref, {ok, Id, Cost}},
                    loop(Updated);
                {error, Reason} ->
                    From ! {Ref, {error, Reason}},
                    loop(Flight)
            end;
        {get, From, Ref} ->
            From ! {Ref, Flight},
            loop(Flight);
        stop ->
            ok
    end.
