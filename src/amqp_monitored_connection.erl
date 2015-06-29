-module(amqp_monitored_connection).

-behavior(gen_server).

-export([start_link/2, get_connection/1]).

-export([init/1, terminate/2, code_change/3, handle_cast/2, handle_info/2, handle_call/3]).

-include_lib("amqp_client/include/amqp_client.hrl").

-type amqp_connection_settings() :: #amqp_params_direct{} | #amqp_params_network{}.

-type name_spec() :: tuple('local',Name::atom()) | tuple('global',GlobalName::term()) | tuple('via',Module::module(),ViaName::term()).

-spec start_link(NameSpec::name_spec(), ConnectionSettings::amqp_connection_settings()) -> tuple('ok',pid()) | 'ignore' | tuple('error',Error::term()).
start_link(NameSpec, ConnectionSettings) -> gen_server:start_link(NameSpec, ?MODULE, ConnectionSettings).

-spec get_connection(NameSpec::name_spec()) -> pid().
get_connection(NameSpec) -> gen_server:call(convert_namespec(NameSpec), get_connection).

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

%% @private
convert_namespec({local, Name}) -> Name;
convert_namespec(NS) -> NS. 
