-module(amqp_monitored_connection).

-behavior(gen_server).

-export([start_link/2, get_connection/1]).

-export([init/1, terminate/2, code_change/3, handle_cast/2, handle_info/2, handle_call/3]).

start_link(NameSpec, ConnectionSettings) -> gen_server:start_link(NameSpec, ?MODULE, ConnectionSettings).

get_connection(NameSpec) -> gen_server:call(NameSpec, get_connection).

%% @private
init(ConnectionSettings) ->
	case catch(amqp_connection:start(ConnectionSettings)) of
		{ok, Connection} ->
			erlang:monitor(process, Connection),
			{ok, {ConnectionSettings, Connection}};
		{error, Error} -> {stop, {connection_failed, Error}}
	end.

%% @private
terminate(_, {_, Connection}) ->
	amqp_connection:close(Connection).

%% @private
code_change(_,State,_) -> {ok, State}.

%% @private
handle_cast(_,State) -> {noreply, State}.

%% @private
handle_call(get_connection,_,{ConnectionSettings,Connection}) -> {reply, Connection, {ConnectionSettings,Connection}}.

%% @private
handle_info(Info, {ConnectionSettings,Connection}) -> 
	case Info of
		{'DOWN', _, _, Pid, DeathInfo} -> {stop, {connection_died, ConnectionSettings, Pid, DeathInfo}, {ConnectionSettings,Connection}};
		_ -> {noreply, {ConnectionSettings, Connection}}
	end.
