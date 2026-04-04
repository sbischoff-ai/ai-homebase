# Channel Binding Reference

Read this file when the user asks to set up, change, or inspect how agents are connected
to messaging channels. Do not load it proactively in every session.

## Concepts

**Channel binding** pins inbound messages from a channel/account to a specific agent:
`openclaw agents bind --agent <id> --bind <channel[:accountId]>`

**Outbound routing** is automatic: replies go back to the channel the message came from.
Outbound-only agents (watchdog, workers) do not need a binding — they route via the session's
`lastRoute` or via explicit `openclaw message` calls in their cron prompts.

Routing priority (most to least specific):
1. Exact peer match
2. Account match
3. Channel-wide wildcard (`accountId: "*"`)
4. Default agent

## Main's primary channel

Main should be bound to the user's primary messaging channel.
Main is the only agent that receives inbound messages on this channel.

```
openclaw agents bind --agent main --bind <channel[:accountId]>
```

Do not bind watchdog, workers, or other agents to receive from the user's primary channel.

## Watchdog and worker notifications

Watchdog and workers that push alerts or deliverables to the user directly do not need a binding.
They route outbound through `lastRoute` (set when the user last messaged from that channel),
or via an explicit `openclaw message --channel <channel> --account <accountId>` call in the cron prompt.

Never bind watchdog or workers to receive inbound messages from the user's primary channel.

## Dedicated agent channels (optional)

If the user wants a direct conversation with a specific agent, create a separate bot/account
on that platform and bind it to that agent only:

```
openclaw agents bind --agent <agent-id> --bind <channel>:<dedicated-account-id>
```

The user messages that separate bot/account to reach the agent directly.
The architect is a natural first choice given its general-purpose design and thinking scope.
Workers that accept user triggers (rather than running only on a schedule) may also warrant
a dedicated channel — this should be specified in their definition package.

## Inspecting and managing bindings

```
openclaw agents list --bindings                                    # all agents and their bindings
openclaw agents bindings --agent <id>                              # bindings for one agent
openclaw agents unbind --agent <id> --bind <channel[:accountId]>   # remove a binding
openclaw agents unbind --agent <id> --all                          # remove all bindings
```
