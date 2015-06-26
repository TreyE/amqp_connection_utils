-module(amqp_monitored_consumer).

-behavior(gen_server).

-export([start_link/2]).

-export([init/1, terminate/2, code_change/3, handle_cast/2, handle_info/2, handle_call/3]).

start_link(NameSpec, Settings) -> gen_server:start_link(NameSpec, ?MODULE, Settings).

-include("amqp_client.hrl").

%% @private
init({ConnectionNameSpec, Subscription, CallbackMod}) ->
	case catch(open_channel(ConnectionNameSpec)) of
		{ok, Channel, Connection} ->
			erlang:monitor(process, Channel),
			create_consumer(Connection, Channel, Subscription, CallbackMod);
		{error, Error} -> {stop, {open_channel_failed, Error}}
	end.

create_consumer(Connection, Channel, Subscription, CallbackMod) ->
	amqp_channel:call(Channel, #'basic.qos'{prefetch_count = 1}),
	case catch(amqp_channel:subscribe(Channel, Subscription, self())) of
		ok -> {ok, {Connection, Channel, CallbackMod}};
		A -> {stop, {subscribe_failed, A}}
	end.

open_channel(ConnectionNameSpec) -> 
	Connection = amqp_monitored_connection:get_connection(ConnectionNameSpec),
	{ok, Channel} = amqp_connection:open_channel(Connection),
	{ok, Channel, Connection}.

%% @private
terminate(_, {_, Channel, _}) ->
	amqp_channel:close(Channel).

%% @private
code_change(_,State,_) -> {ok, State}.

%% @private
handle_cast(_,State) -> {noreply, State}.

%% @private
handle_call(_, _, State) -> {reply, ok, State}.

%% @private
handle_info(Info, {Connection,Channel,CallbackMod}) -> 
	case Info of
		{'DOWN', _, _, Pid, DeathInfo} -> {stop, {channel_died, Connection, Channel, Pid, DeathInfo}, {Connection, Channel, CallbackMod}};
		%% TODO: Add callback mod invocation
		_ -> {noreply, {Connection, Channel, CallbackMod}}
	end.
