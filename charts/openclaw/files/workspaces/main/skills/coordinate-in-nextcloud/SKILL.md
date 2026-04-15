---
name: coordinate-in-nextcloud
description: Use when operating Nextcloud as the shared coordination layer for desk state, calendars, todos, tables, sharing, or coordination status.
---

# Nextcloud Coordination

Main owns shared coordination state, not specialist project authorship.

## Main's Nextcloud Scope

Use Nextcloud for:
- Nextcloud `/Desk/` shared continuity and live indexing
- Nextcloud `/Projects/` sharing and top-level coordination
- user-facing status docs and shared outputs
- calendars, todos, reminders, and tables when they improve collaboration
- Nextcloud `/Projects/ai-homebase/coordination-status.json`
- quiet background collaboration in the shared `openclaw` account before something is intentionally shared with the user's own account

Do not use Nextcloud to:
- author detailed project specs or durable task breakdowns that belong with architect
- store code
- duplicate large specialist deliverables in chat
- replace local workspace WIP or Qdrant for private rough thinking and quick recall

## Procedure

1. Treat all Nextcloud paths as remote paths.
2. On first use, ensure Nextcloud `/Desk/`, Nextcloud `/Desk/current.md`, Nextcloud `/Desk/index.md`, and Nextcloud `/Desk/daily/README.md` exist.
3. Create missing parent directories before writing.
4. Before major coordination, read Nextcloud `/Desk/current.md`, Nextcloud `/Desk/index.md`, and the latest shared daily note when they exist.
5. Review only the calendars, tasks, and tables registered for orientation, active coordination, or another explicitly scheduled review.
6. Default to a one-day lookback and seven-day lookahead for registered calendars and task lists unless the surface says otherwise.
7. For user-facing project work, check whether Nextcloud `/Projects/<slug>/` already exists.
8. If the task is durable planning, route it to architect rather than writing the artifact yourself.
9. If the task is implementation context or runbook material, route it to coder.
10. Prefer calendar or tasks for commitments, reminders, and follow-through instead of burying them in markdown.
11. Prefer tables when the user needs a repeatedly updated structured overview.
12. Register new folders outside Nextcloud `/Projects/<slug>/`, relevant calendars, task lists, tables, and user-shared folders in Nextcloud `/Desk/index.md`.
13. Each Nextcloud `/Desk/index.md` entry should include `type`, stable `id` or path, purpose, steward, project or domain, and a read trigger.
14. Use shares when an artifact should become user-visible outside the agent loop.
15. When shared coordination state changes in a way watchdog should notice, update Nextcloud `/Projects/ai-homebase/coordination-status.json`.
16. When durable facts or rules are created, store a Qdrant summary with `project`, `tags`, and `nc_refs`, plus `expiry` when the memory is intentionally short-lived.

Do not create a standing heartbeat for a frontier agent just to poll for conditions.
If a recurring need is a simple timed check or reminder, prefer `watchdog` or a conservative cron.
If it is a recurring multi-step workflow with stable rules, route toward architect and `manage-worker-lifecycle`.
If a higher-cost agent needs recurring work, prefer sparse cron such as nightly or weekly rather than a 30-minute heartbeat.
Do not let Nextcloud `/Desk/` become a generic archive; move stable material into Qdrant, Memgraph, or Nextcloud `/Projects/`.

## Common Paths

- Nextcloud `/Desk/current.md`
- Nextcloud `/Desk/index.md`
- Nextcloud `/Desk/daily/`
- Nextcloud `/Projects/<slug>/status.md`
- Nextcloud `/Projects/<slug>/outputs/`
- Nextcloud `/Projects/ai-homebase/coordination-status.json`

## Escalate

- when project-folder authorship should belong to architect
- when the user asks for durable technical notes that belong with coder
