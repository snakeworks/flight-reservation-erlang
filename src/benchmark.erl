-module(benchmark).
-include("base.hrl").
-export([exp1/0, exp1/2, exp2/0, exp3/0]).

-define(REPETITIONS, 5).

print_header() ->
    io:format("threads,flights,customers,iteration,time_ms~n").

print_row(Threads, Flights, Customers, Iteration, TimeMs) ->
    io:format("~b,~b,~b,~b,~.1f~n", [Threads, Flights, Customers, Iteration, TimeMs]).

%% Experiment 1 - scaling threads
%% Vary the number of scheduler threads from 1..MaxThreads, and measure how long
%% it takes to process every customer.

exp1() -> exp1(256, 1000000).

exp1(FlightCount, CustomerCount) ->
    MaxThreads = erlang:system_info(schedulers), % NOTE: Might report more because of SMT
    {Flights, Customers} = make_testing_data(FlightCount, CustomerCount),
    print_header(),
    [print_row(ThreadCount, FlightCount, CustomerCount, Rep, run(ThreadCount, Flights, Customers) / 1000)
        || ThreadCount <- lists:seq(1, MaxThreads),
        Rep <- lists:seq(1, ?REPETITIONS)],
    ok.

%% Experiment 2 - best case
%% No contention, one customer per flight, so no two customers ever wait on
%% the same flight process, at max threads. Vary the load and measure the time
%% to process it.

-define(EXP2_LOADS, [1000, 10000, 100000, 1000000]).

exp2() ->
    MaxThreads = erlang:system_info(schedulers), % NOTE: Might report more because of SMT
    print_header(),
    [begin
         {Flights, Customers} = make_testing_data(CustomerCount, CustomerCount),
         [print_row(MaxThreads, CustomerCount, CustomerCount, Rep, run(MaxThreads, Flights, Customers) / 1000)
          || Rep <- lists:seq(1, ?REPETITIONS)]
     end || CustomerCount <- ?EXP2_LOADS],
    ok.

%% Experiment 3 - contention worst case
%% Fixed load and threads, and shrink the number of flights so more and more
%% customers funnel through each flight process.

-define(FLIGHT_COUNTS, [1, 2, 4, 8, 16, 32, 64, 128, 256]).
-define(EXP3_LOAD, 1000000).

exp3() ->
    MaxThreads = erlang:system_info(schedulers), % NOTE: Might report more because of SMT
    print_header(),
    [begin
         {Flights, Customers} = make_testing_data(FlightCount, ?EXP3_LOAD),
         [print_row(MaxThreads, FlightCount, ?EXP3_LOAD, Rep, run(MaxThreads, Flights, Customers) / 1000)
          || Rep <- lists:seq(1, ?REPETITIONS)]
     end || FlightCount <- ?FLIGHT_COUNTS],
    ok.

run(ThreadCount, Flights, Customers) ->
    Prev = erlang:system_flag(schedulers_online, ThreadCount),
    system:init(),
    [system:add_flight(F) || F <- Flights],
    Parent = self(),
    % Split the customers over a small pool of workers, one per core
    ChunkSize = (length(Customers) + ThreadCount - 1) div ThreadCount,
    Workers = [spawn(fun() ->
                   receive go -> ok end,
                   [system:reserve(C) || C <- Chunk],
                   Parent ! done
                end) || Chunk <- chunks(Customers, ChunkSize)],
    {ElapsedTime, _} = timer:tc(fun() ->
        [W ! go || W <- Workers],
        [receive done -> ok end || _ <- Workers]
    end),
    system:stop(),
    erlang:system_flag(schedulers_online, Prev),
    ElapsedTime.

%% Split a list into contiguous chunks of at most Size elements.
chunks([], _Size) -> [];
chunks(List, Size) when length(List) =< Size -> [List];
chunks(List, Size) ->
    {Head, Tail} = lists:split(Size, List),
    [Head | chunks(Tail, Size)].

make_testing_data(FlightCount, CustomerCount) ->
    Flights = [base:flight(I, "HUB", "D" ++ integer_to_list(I), "Carrier",
                           [base:tier(100, CustomerCount, 0)])
               || I <- lists:seq(0, FlightCount - 1)],
    Customers = [base:customer(Id, "HUB", "D" ++ integer_to_list(Id rem FlightCount), 1, 100)
                 || Id <- lists:seq(0, CustomerCount - 1)],
    {Flights, Customers}.
