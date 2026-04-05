---
name: channel_binding
description: Use when main needs to set up, inspect, or change messaging channel bindings for the user or a dedicated specialist channel. Covers binding rules, inspection, and safe ownership boundaries.
---

# Channel Binding

Use this skill when channel setup or inspection is part of the task.

## Rules

- Main is the only agent bound to the user's primary inbound channel.
- Do not bind watchdog or workers to receive inbound user traffic on the primary channel.
- Dedicated specialist channels require a separate bot or account for that agent.

## Procedure

1. Read `CHANNELS.md`.
2. Determine whether the task is:
   - primary channel binding for main
   - dedicated channel binding for a specific specialist
   - inspection or cleanup of existing bindings
3. Use the OpenClaw CLI forms documented in `CHANNELS.md`:
   - `openclaw agents bind --agent <id> --bind <channel[:accountId]>`
   - `openclaw agents list --bindings`
   - `openclaw agents bindings --agent <id>`
   - `openclaw agents unbind --agent <id> --bind <channel[:accountId]>`
4. Explain the resulting routing clearly to the user.
5. Once the primary channel is set, ask whether a dedicated specialist channel is also wanted. Architect is the usual first candidate.

## Escalate

- if the requested channel topology would route inbound user traffic away from main without an explicit dedicated-agent pattern
- if the account or channel identifiers are missing
