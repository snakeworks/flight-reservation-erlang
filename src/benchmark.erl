-module(benchmark).
-include("base.hrl").
-export([exp1/0, exp1/2]).

%% Experiment 1 - scaling threads
%% Vary the number of scheduler threads from 1..MaxThreads, and measure how long
%% it takes to process every customer.

-define(REPETITIONS, 5).

exp1() -> exp1(256, 1000000).

exp1(FlightCount, CustomerCount) ->
    MaxThreads = erlang:system_info(schedulers), % NOTE: Might report more because of SMT
    {Flights, Customers} = make_testing_data(FlightCount, CustomerCount),
    io:format("threads,customers,iteration,time_ms~n"),
    [io:format("~b,~b,~b,~.1f~n", [ThreadCount, CustomerCount, Rep, run(ThreadCount, Flights, Customers) / 1000])
     || ThreadCount <- lists:seq(1, MaxThreads),
        Rep <- lists:seq(1, ?REPETITIONS)],
    ok.

run(ThreadCount, Flights, Customers) ->
    Prev = erlang:system_flag(schedulers_online, ThreadCount),
    system:init(),
    [system:add_flight(F) || F <- Flights],
    Parent = self(),
    {ElapsedTime, _} = timer:tc(fun() ->
        [spawn(fun() -> Parent ! {done, system:reserve(C)} end) || C <- Customers],
        [receive {done, _} -> ok end || _ <- Customers]
    end),
    system:stop(),
    erlang:system_flag(schedulers_online, Prev),
    ElapsedTime.

make_testing_data(FlightCount, CustomerCount) ->
    Flights = [base:flight(I, "HUB", "D" ++ integer_to_list(I), "Carrier",
                           [base:tier(100, CustomerCount, 0)])
               || I <- lists:seq(0, FlightCount - 1)],
    Customers = [base:customer(Id, "HUB", "D" ++ integer_to_list(Id rem FlightCount), 1, 100)
                 || Id <- lists:seq(0, CustomerCount - 1)],
    {Flights, Customers}.
