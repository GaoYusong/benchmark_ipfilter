-module(main).
-author("yusong.gao@gmail.com").
-compile(export_all).

test(N) when N > 0 ->
    %%{A1,A2,A3} = now(),
    %%random:seed(A1, A2, A3),
    Index = N div 2 + 1,
    IPS = gen_ips(N),
    IP = hd(string:tokens(lists:nth(Index, IPS), "/")),
    io:format("IP: ~s~n", [IP]),
    %%io:format("IPS: ~p~n", [IPS]),
    {test(IP, IPS, check_algo_x, fun check_algo_x/2, fun pre_algo_x/1),
     test(IP, IPS, check_algo_y, fun check_algo_y/2, fun pre_algo_y/1),
     test(IP, IPS, check_algo_z, fun check_algo_z/2, fun pre_algo_z/1)}.

test(IP, IPS0, Tag, Func, PreFunc)  ->
    M = 100000,
    IPS = PreFunc(IPS0),
    Begin = now(),
    run(M, fun() -> Func(IP, IPS) end),
    Time = timer:now_diff(now(), Begin),
    
    {Tag, Time, M / Time * 1000000, Func(IP, IPS)}.

run(N, Func) when N > 0 ->
    Func(),
    run(N - 1, Func);
run(0, _) ->
    ok.

gen_ips(N) when N > 0 ->
    [gen_cidr() | gen_ips(N - 1)];
gen_ips(0) ->
    [].

gen_cidr() ->
    lists:flatten(io_lib:format("~w.~w.~w.~w/~w", [random:uniform(256) - 1,
                                                   random:uniform(256) - 1,
                                                   random:uniform(256) - 1,
                                                   random:uniform(256) - 1,
                                                   random:uniform(33) - 1])).

%%====================================================================
%% algo x
%%====================================================================

check_algo_x(Ip, Filters) when is_list(Ip) ->
    {ok, {A,B,C,D}} = inet_parse:address(Ip),
    check_algo_x({A,B,C,D}, Filters);

check_algo_x(Ip, Filters) when is_tuple(Ip)->
    lists:any(
      fun(Filter)->
              {ok, {Ip1, Bit}} = parse_ip_filter(Filter),
              Mask = -1 bsl (32-Bit),
              (inet_ntoa(Ip) band Mask) =:= (inet_ntoa(Ip1) band Mask)
      end,
      Filters).

pre_algo_x(IPS) ->
    IPS.

parse_ip_filter(Ip)->
    case string:tokens(Ip, "/") of
        [MaskStr] -> parse_ip_filter(MaskStr, 32);
        [MaskStr, BitString] ->
            case string:to_integer(BitString) of
                {Bit, []} when Bit >= 0 andalso Bit =< 32 ->
                    parse_ip_filter(MaskStr, Bit);
                _ ->
                    {error, illegal_bit}
            end
    end.

parse_ip_filter(MaskStr, Bit) ->
    case inet_parse:address(MaskStr) of
        {ok, Mask} -> {ok, {Mask, Bit}};
        {error, _Error} ->
            {error, illegal_mask}
    end.

inet_ntoa({A,B,C,D}) -> (A bsl 24) + (B bsl 16) + (C bsl 8) + D.

%%====================================================================
%% algo y
%%====================================================================

check_algo_y(IP, IPS) ->
    {ok, IP0} = inet_parse:address(IP),
    do_check_algo_y(32, inet_ntoa(IP0), IPS).

do_check_algo_y(Mask, IP, IPS) when Mask >= 0 ->
    is_member(IP band (-1 bsl (32 - Mask)), IPS) orelse do_check_algo_y(Mask - 1, IP, IPS);
do_check_algo_y(-1, _, _) ->
    false.

pre_algo_y(IPS) ->
    create_sets([to_prefix_int(CIDR) || CIDR <- IPS]).

create_sets(L) ->
    R = ets:new(ips_sets, []),
    [ets:insert(R, {X, 1}) || X <- L],
    %%io:format("~w", [ets:tab2list(R)]),
    R.

is_member(X, L) ->
    ets:member(L, X).
    
to_prefix_int(CIDR) ->
    {N0, Mask} = fmt_cidr(CIDR),
    {ok, Addr} = inet_parse:address(N0),
    inet_ntoa(Addr) band (-1 bsl (32 - Mask)).

fmt_cidr(CIDR) ->
    case string:tokens(CIDR, "/") of
        [N] ->
            {N, 32};
        [N, M] ->
            {N, list_to_integer(M)}
    end.

%%====================================================================
%% algo z
%%====================================================================

check_algo_z(IP, IPS) ->
    {ok, Addr} = inet_parse:address(IP),
    find_trie(inet_ntoa(Addr), 32, IPS).


pre_algo_z(IPS) ->
    R = lists:foldl(
          fun(CIDR, Acc) ->
                  {N0, Mask} = fmt_cidr(CIDR),
                  {ok, Addr} = inet_parse:address(N0),
                  insert_trie(inet_ntoa(Addr) bsr (32 - Mask), Mask, Acc)
          end, new_trie(), IPS),
    io:format("~p~n", [element(1, R)]),
    R.


new_trie() ->
    {0, nil}.

insert_trie(Val, Len, {Size, Trie}) ->
    insert_trie_1(<<Val:Len>>, Len, Trie, Size).

insert_trie_1(_, _, {1, _, _} = Trie, Size) ->
    {Size, Trie};
insert_trie_1(A, B, nil, Size) ->
    {Size1, Trie} = insert_trie_1(A, B, {0, nil, nil}, Size),
    {Size1 + 1, Trie};
insert_trie_1(<<>>, 0, {0, LC, RC}, Size) ->
    {Size, {1, LC, RC}};
insert_trie_1(Val, Len, {0, LC, RC}, Size) ->
    Rest = Len - 1,
    case Val of
        <<0:1, T:Rest>> ->
            {Size1, LC1} = insert_trie_1(<<T:Rest>>, Len - 1, LC, Size),
            {Size1, {0, LC1, RC}};
        <<1:1, T:Rest>> ->
            {Size1, RC1} = insert_trie_1(<<T:Rest>>, Len - 1, RC, Size),
            {Size1, {0, LC, RC1}}
    end.

find_trie(Val, Len, {_, Trie}) ->
    find_trie_1(<<Val:Len>>, Len, Trie).

find_trie_1(_, _, nil) -> 
    false;
find_trie_1(_, _, {1, _, _}) -> 
    true;
find_trie_1(<<>>, 0, {0, _, _}) -> 
    false;
find_trie_1(Val, Len, {0, LC, RC}) -> 
    Rest = Len - 1,
    case Val of
        <<0:1, T:Rest>> ->
            find_trie_1(<<T:Rest>>, Len - 1, LC);
        <<1:1, T:Rest>> ->
            find_trie_1(<<T:Rest>>, Len - 1, RC)
    end.


