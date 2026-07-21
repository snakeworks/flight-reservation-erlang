-module(base).
-include("base.hrl").
-export([tier/3, flight/5, customer/5]).

% NOTE: Always use these constructors instead of creating records manually!!

tier(Price, Available, Occupied)
  when is_integer(Price), Price >= 0,
    is_integer(Available), Available >= 0,
    is_integer(Occupied), Occupied >= 0 ->
      #tier{price = Price, available = Available, occupied = Occupied}.

flight(Id, From, To, Carrier, Pricing)
  when is_integer(Id), Id >= 0, is_list(Pricing) ->
    Sorted = lists:sort(fun(#tier{price = P1}, #tier{price = P2}) -> P1 =< P2 end, Pricing), % Sort prices from cheapest upfront
    #flight{id = Id, from = From, to = To, carrier = Carrier, pricing = Sorted}.

customer(Id, From, To, Seats, Budget)
  when is_integer(Id), Id >= 0,
      is_integer(Seats), Seats >= 0,
      is_integer(Budget), Budget >= 0 ->
    #customer{id = Id, from = From, to = To, seats = Seats, budget = Budget}.
