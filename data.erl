-module(data).
-include("base.hrl").

%% Constructors for the reservation system's data model.
-export([tier/3, flight/5, customer/5]).

%% tier(Price, Available, Occupied) -> #tier{}
tier(Price, Available, Occupied)
  when is_integer(Price), Price >= 0,
       is_integer(Available), Available >= 0,
       is_integer(Occupied), Occupied >= 0 ->
    #tier{price = Price, available = Available, occupied = Occupied}.

%% flight(Id, From, To, Carrier, Pricing) -> #flight{}
%% Pricing is a list of #tier{} records.
flight(Id, From, To, Carrier, Pricing)
  when is_integer(Id), Id >= 0, is_list(Pricing) ->
    #flight{id = Id, from = From, to = To,
            carrier = Carrier, pricing = Pricing}.

%% customer(Id, From, To, Seats, Budget) -> #customer{}
customer(Id, From, To, Seats, Budget)
  when is_integer(Id), Id >= 0,
       is_integer(Seats), Seats >= 0,
       is_integer(Budget), Budget >= 0 ->
    #customer{id = Id, from = From, to = To,
              seats = Seats, budget = Budget}.
