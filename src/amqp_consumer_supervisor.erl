-module(amqp_consumer_supervisor).

-export([init/1, generate_child_specs/5, start_link/5]).

start_link(ConnectionNameSpec, Subscription, CallbackMod, ModArgs, Count) -> supervisor:start_link(?MODULE, {ConnectionNameSpec, Subscription, CallbackMod, ModArgs, Count}).

init({ConnectionNameSpec, Subscription, CallbackMod, ModArgs, Count}) -> {
ok,
{sup_flags(), generate_child_specs(ConnectionNameSpec, Subscription,CallbackMod,ModArgs,Count)}
}.

generate_child_specs(ConnectionNameSpec, Subscription, CallbackMod, Args, Count) -> lists:map(fun(I) -> {
		undefined,
		{amqp_monitored_consumer, start_link, [ConnectionNameSpec,Subscription,CallbackMod, Args, I]},
		permanent,
		5000,
		worker,
		dynamic
	} end,
        lists:seq(1,Count)).

sup_flags() -> {
  one_for_one,
  1,
  5
}.
