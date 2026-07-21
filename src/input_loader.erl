-module(input_loader).
-include("base.hrl").
-export([load/1]).

load(File) ->
    case file:consult(File) of
        {ok, Terms} -> {ok, make_real(Terms, [], [])};
        {error, Reason} -> {error, Reason}
    end.

make_real([], Flights, Customers) ->
    {lists:reverse(Flights), lists:reverse(Customers)};
make_real([{flight, Id, From, To, Carrier, Pricing} | Rest], Flights, Customers) ->
    Flight = base:flight(Id, From, To, Carrier,
                         [base:tier(P, A, O) || {P, A, O} <- Pricing]),
    make_real(Rest, [Flight | Flights], Customers);
make_real([{customer, Id, From, To, Seats, Budget} | Rest], Flights, Customers) ->
    Customer = base:customer(Id, From, To, Seats, Budget),
    make_real(Rest, Flights, [Customer | Customers]).
