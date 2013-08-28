%% @doc A corral for holding Zeta clients

%% A corral is a one_for_one supervisor which holds on to the Zeta
%% client workers. Zeta clients are not robust! They are expected to
%% die at times and for long times---such as when Riemann itself is
%% unreachable---without necessarily mandating total release shutdown
%% as the original, naive implementation did.

%% Thus, they are `transient' processes and _corral has a sensible way
%% of creating new on the fly.

-module(zeta_corral).
-author('Joseph Abrahamson <me@jspha.com>').

-export([client/0, client/1]).

-export([start_link/0]).

-behaviour(supervisor).
-define(SUP, ?MODULE).
-export([init/1]).



%% Public API
%% ----------

-spec
%% @equiv client(default).
client() -> {ok, pid()} | {error, any()}.
client() -> client(default).

-spec
client(Name :: atom()) -> {ok, pid()} | {error, any()}.
client(Name) ->
    Children = [Pid ||
        {N, Pid, _, _} <- supervisor:which_children(?SUP), N =:= Name],
    case Children of
        [] ->
            start_client(Name);
        [Pid|_] ->
            {ok, Pid}
    end.

start_client(Name) ->
    case zeta:client_config(Name) of
        {ok, {Host, Port, _}} ->
            case start_client(Name, Host, Port) of
                {error, {already_started, Pid}} -> {ok, Pid};
                {ok, Pid} -> {ok, Pid};
                {error, Reason} -> {error, Reason}
            end;
        {error, _} = Error ->
            Error
    end.

start_client(Name, Host, Port) ->
      supervisor:start_child(
	?SUP,
	{Name, {zeta_client, start_link, [Host, Port]},
	 temporary, brutal_kill, worker, [zeta_client]}).


%% Lifecycle API
%% -------------

start_link() ->
    supervisor:start_link({local, ?SUP}, ?MODULE, []).

%% Supervisor API
%% --------------

init(_Args) ->
    {ok, {{one_for_one, 5, 10}, []}}.
