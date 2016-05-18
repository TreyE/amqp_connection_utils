-module(amqp_consumer_tree).

-export([generate_supervisor_specs/6, generate_supervisor_specs/7]).

-include_lib("amqp_client/include/amqp_client.hrl").

-type name_spec() :: {'local',Name::atom()} | {'global',GlobalName::term()} | {'via',Module::module(),ViaName::term()}.
-type subscription() :: #'basic.consume'{}.
-type amqp_connection_settings() :: #amqp_params_direct{} | #amqp_params_network{}.

-spec generate_supervisor_specs(NameSpec::name_spec(), ConnectionSettings::amqp_connection_settings(), Subscription::subscription(), CallbackMod::module(), ModArgs::term(), Count::integer()) -> term().
generate_supervisor_specs(
	NameSpec,
	ConnectionSettings,
	Subscription,
	CallbackMod,
	ModArgs,
	Count) -> 
generate_supervisor_specs(
	NameSpec,
	ConnectionSettings,
	Subscription,
	CallbackMod,
	ModArgs,
	Count,
	[]).

-spec generate_supervisor_specs(NameSpec::name_spec(), ConnectionSettings::amqp_connection_settings(), Subscription::subscription(), CallbackMod::module(), ModArgs::term(), Count::integer(), OtherSpecs::list(term())) -> term().
generate_supervisor_specs(
	NameSpec,
	ConnectionSettings,
	Subscription,
	CallbackMod,
	ModArgs,
	Count,
	OtherSpecs
) -> {ok, {
{one_for_all, 3, 5},
([
{amqp_connection_mon,
  {amqp_monitored_connection, start_link, [NameSpec, ConnectionSettings]},
  permanent,
  5000,
  worker,
  dynamic
},
{amqp_consumer_mon_sup,
  {amqp_consumer_supervisor, start_link, [NameSpec, Subscription, CallbackMod, ModArgs, Count]},
  permanent,
  infinity,
  supervisor,
  dynamic
}] ++ OtherSpecs)}}.
