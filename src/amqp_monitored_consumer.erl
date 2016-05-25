-module(amqp_monitored_consumer).

-behavior(gen_server).

-export([start_link/5]).

-export([init/1, terminate/2, code_change/3, handle_cast/2, handle_info/2, handle_call/3]).

-include_lib("amqp_client/include/amqp_client.hrl").

-type cancel_ok() :: #'basic.cancel_ok'{}.
-type consume_ok() :: #'basic.consume_ok'{}.
-type subscription() :: #'basic.consume'{}.
-type delivery_info() :: #'basic.deliver'{}.
-type name_spec() :: {'local',Name::atom()} | {'global',GlobalName::term()} | {'via',Module::module(),ViaName::term()}.

-callback init_consumer(Connection::pid(), Channel::pid(), Args::term()) -> {'ok', State::term()} | {'stop', Reason::term()}.

-callback handle_cancel_ok(State::term(), Channel::pid(), CanOK::cancel_ok()) -> {'ok', State::term()}.

-callback handle_consume_ok(State::term(), Channel::pid(), ConOK::consume_ok()) -> {'ok', State::term()}.

-callback handle_message(State::term(), Channel::pid(), DeliveryInfo::delivery_info(), Content::term()) -> {'ok', State::term()}.

-spec start_link(NameSpec::name_spec(), Subscription::subscription(), CallbackMod::module(), Args::term(), Idx::integer()) -> {'ok',pid()} | 'ignore' | {'error',Error::term()}.
start_link(NameSpec, Subscription, CallbackMod, Args, Idx) -> gen_server:start_link(gen_name(CallbackMod, Idx), ?MODULE, {NameSpec, Subscription, CallbackMod, Args}, []).

%% @private
init({ConnectionNameSpec, Subscription, CallbackMod, Args}) ->
	case catch(open_channel(ConnectionNameSpec)) of
		{ok, Channel, Connection} ->
			erlang:monitor(process, Channel),
			init_module_state(Connection, Channel, Subscription, CallbackMod, Args);
		{error, Error} -> {stop, {open_channel_failed, Error}}
	end.

%% @private
init_module_state(Connection, Channel, Subscription, CallbackMod, Args) ->
	case catch(CallbackMod:init_consumer(Connection, Channel, Args)) of
	        {ok, State} -> create_consumer(Connection, Channel, Subscription, CallbackMod, State);
	        {stop, Reason} -> {stop, {consumer_init_stop, Reason}};
		A -> {stop, {consumer_init_error, A}} 
	end.

%% @private
create_consumer(Connection, Channel, Subscription, CallbackMod, ModState) ->
	case catch(amqp_channel:subscribe(Channel, Subscription, self())) of
		ok -> {ok, {Connection, Channel, CallbackMod, ModState}};
		#'basic.consume_ok'{} -> {ok, {Connection, Channel, CallbackMod, ModState}};
		A -> {stop, {subscribe_failed, A}}
	end.

open_channel(ConnectionNameSpec) -> 
	Connection = amqp_monitored_connection:get_connection(ConnectionNameSpec),
	{ok, Channel} = amqp_connection:open_channel(Connection),
	{ok, Channel, Connection}.

%% @private
terminate(_, {_, Channel, _, _}) ->
	amqp_channel:close(Channel).

%% @private
code_change(_,State,_) -> {ok, State}.

%% @private
handle_cast(_,State) -> {noreply, State}.

%% @private
handle_call(_, _, State) -> {reply, ok, State}.

%% @private
handle_info(Info, {Connection,Channel,CallbackMod,ModState}) -> 
	case Info of
		{'DOWN', _, _, Pid, DeathInfo} -> {stop, {channel_died, Connection, Channel, Pid, DeathInfo}, {Connection, Channel, CallbackMod, ModState}};
		{DI = #'basic.deliver'{}, Content} -> invoke_module_message(Connection, Channel, CallbackMod, ModState, DI, Content);
		ConOK = #'basic.consume_ok'{} -> invoke_module_consume_ok(Connection, Channel, CallbackMod, ModState, ConOK);
		CanOK = #'basic.cancel_ok'{} -> invoke_module_cancel_ok(Connection, Channel, CallbackMod, ModState, CanOK);
		%% TODO: Add callback mod invocation
		_ -> {noreply, {Connection, Channel, CallbackMod}}
	end.

%% @private
invoke_module_message(Connection, Channel, CallbackMod, ModState, DI, Content) -> 
	case catch(CallbackMod:handle_message(ModState, Channel, DI, Content)) of
		{ok,State} -> {noreply, {Connection, Channel, CallbackMod, State}};
		A ->    
			amqp_channel:close(Channel),
			{stop, {handle_message_error, DI, Content, Connection, Channel, CallbackMod, ModState, A}, {Connection,Channel,CallbackMod,ModState}}
	end.

%% @private

%% @private
invoke_module_consume_ok(Connection, Channel, CallbackMod, ModState, ConOK) ->
	case catch(CallbackMod:handle_consume_ok(ModState, Channel, ConOK)) of
		{ok, State} -> {noreply, {Connection, Channel, CallbackMod, State}};
		A ->
			amqp_channel:close(Channel),
			{stop, {handle_consume_ok_error, ConOK, Connection, Channel, CallbackMod, ModState, A}, {Connection,Channel,CallbackMod,ModState}}
	end.

%% @private
invoke_module_cancel_ok(Connection, Channel, CallbackMod, ModState, CanOK) ->
	case catch(CallbackMod:handle_cancel_ok(ModState, Channel, CanOK)) of
		{ok, State} -> {noreply, {Connection, Channel, CallbackMod, State}};
		A ->
			amqp_channel:close(Channel),
			{stop, {handle_consume_ok_error, CanOK, Connection, Channel, CallbackMod, ModState, A}, {Connection,Channel,CallbackMod,ModState}}
	end.

%% @private
gen_name(CallbackMod, I) -> 
	{local, erlang:list_to_atom("amqp_dynamic_consumer_" ++ erlang:atom_to_list(CallbackMod) ++ "_" ++ erlang:integer_to_list(I))}.
