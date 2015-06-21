-module(amqp_monitored_connection).

-include("amqp_client.hrl").

-behavior(gen_server).

-export([init/1, terminate/2, code_change/3, handle_cast/2, handle_info/2, handle_call/3]).

init(ConnectionSettings) ->
	case catch(amqp_connection:start(ConnectionSettings)) of
		{ok, Connection} ->
			erlang:monitor(process, Connection),
			{ok, {ConnectionSettings, Connection}};
		{error, Error} -> {stop, {connection_failed, Error}}
	end.

terminate(_, {_, Connection}) ->
	amqp_connection:close(Connection).

code_change(_,State,_) -> {ok, State}.

handle_cast(_,State) -> {noreply, State}.

handle_call(get_connection,_,{ConnectionSettings,Connection}) -> {reply, Connection, {ConnectionSettings,Connection}}.

handle_info(Info, State) -> 
	case Info of
		{'DOWN', _, _, Pid, Info} -> {stop, {connection_died, Pid, Info}, State};
		_ -> {noreply, State}
	end.
