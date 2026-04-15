---
name: bind-channels
description: Use when setting up, inspecting, or changing messaging channel bindings for the user or a dedicated specialist channel.
---

# Channel Binding

Use when channel setup, routing, or binding inspection is part of the task.
Load it only when channel setup, routing, or binding inspection is actually involved.

## Concepts

**Channel binding** pins inbound messages from a channel or account to a specific agent:
`openclaw agents bind --agent <id> --bind <channel[:accountId]>`

**Outbound routing** is automatic: replies go back to the channel the message came from.
Outbound-only agents such as watchdog or workers do not need a binding. They route via the
session's `lastRoute` or through explicit `openclaw message` calls in cron prompts.

Routing priority from most to least specific:
1. Exact peer match
2. Account match
3. Channel-wide wildcard (`accountId: "*"`)
4. Default agent

## Rules

- Main is the only agent bound to the user's primary inbound channel.
- Do not bind watchdog or workers to receive inbound user traffic on the primary channel.
- Dedicated specialist channels require a separate bot or account for that agent.
- Never route inbound user traffic away from main unless the user explicitly wants a dedicated
  specialist channel.

## Procedure

1. Determine whether the task is:
   - primary channel binding for main
   - dedicated channel binding for a specific specialist
   - inspection or cleanup of existing bindings
2. Apply the correct binding pattern:
   - Primary user channel for main:
     `openclaw agents bind --agent main --bind <channel[:accountId]>`
   - Dedicated specialist channel with a separate bot or account:
     `openclaw agents bind --agent <agent-id> --bind <channel>:<dedicated-account-id>`
3. Use these CLI forms for inspection and cleanup:
   - `openclaw agents bind --agent <id> --bind <channel[:accountId]>`
   - `openclaw agents list --bindings`
   - `openclaw agents bindings --agent <id>`
   - `openclaw agents unbind --agent <id> --bind <channel[:accountId]>`
   - `openclaw agents unbind --agent <id> --all`
4. Explain the resulting routing clearly to the user:
   - Main owns the user's primary inbound channel.
   - Replies return through the route the message came from.
   - Watchdog and workers usually send outbound only and do not need inbound bindings.
5. Once the primary channel is set, ask whether a dedicated specialist channel is also wanted.
   Architect is the usual first candidate.

## Escalate

- if the requested channel topology would route inbound user traffic away from main without an explicit dedicated-agent pattern
- if the account or channel identifiers are missing
