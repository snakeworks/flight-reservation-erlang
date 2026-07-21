-record(tier, {
    price    :: non_neg_integer(),
    available :: non_neg_integer(),
    occupied  :: non_neg_integer()
}).

-record(flight, {
    id      :: non_neg_integer(),
    from    :: string(),
    to      :: string(),
    carrier :: string(),
    pricing :: [#tier{}]
}).

-record(customer, {
    id     :: non_neg_integer(),
    from   :: string(),
    to     :: string(),
    seats  :: non_neg_integer(),
    budget :: non_neg_integer()
}).
