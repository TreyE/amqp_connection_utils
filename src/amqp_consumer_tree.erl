-module(amqp_consumer_tree).

-export([generate_supervisor_specs/6]).

generate_supervisor_specs(
	NameSpec,
	ConnectionSettings,
	Subscription,
	CallbackMod,
	ModArgs,
	Count
) -> {ok, {
{one_for_all, 1, 5},
[
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
}]}}.
