---
name: coordinate-in-nextcloud
description: Use when main needs to operate Nextcloud as the shared coordination layer. Covers project folder ownership, sharing, calendars, todos, tables, heartbeat state, and when to hand work to another agent instead of authoring project artifacts directly.
---

# Nextcloud Coordination

Main owns shared coordination state, not specialist project authorship.

## Main's Nextcloud Scope

Use Nextcloud for:
- `/Projects/` sharing and top-level coordination
- user-facing status docs and shared outputs
- calendars, todos, reminders, and tables when they improve collaboration
- `/Projects/ai-homebase/heartbeat.json`

Do not use Nextcloud to:
- author detailed project specs or durable task breakdowns that belong with architect
- store code
- duplicate large specialist deliverables in chat

## Procedure

1. Treat all Nextcloud paths as remote paths.
2. Create missing parent directories before writing.
3. For user-facing project work, check whether `/Projects/<slug>/` already exists.
4. If the task is durable planning, route it to architect rather than writing the artifact yourself.
5. If the task is implementation context or runbook material, route it to coder.
6. Use shares when an artifact should become user-visible outside the agent loop.
7. When heartbeat state changes, update `/Projects/ai-homebase/heartbeat.json`.
8. When durable facts or rules are created, store a Qdrant summary with `nc_refs`.

If a recurring need is a simple timed check or reminder, prefer a cron in main or watchdog.
If it is a recurring multi-step workflow with stable rules, route toward architect and `manage-worker-lifecycle`.

## Common Paths

- `/Projects/<slug>/status.md`
- `/Projects/<slug>/outputs/`
- `/Projects/ai-homebase/heartbeat.json`

## Escalate

- when project-folder authorship should belong to architect
- when the user asks for durable technical notes that belong with coder
