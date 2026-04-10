# Tools

Local notes for this setup.

## Files

- Files in this workspace are local workspace files.
- Use local workspace files for private WIP, rough drafts, and self-management notes.
- `/Projects/...` are Nextcloud remote paths owned by the shared `openclaw` Nextcloud account, which is separate from the user's own Nextcloud account.
- Shared ai-homebase files you will check often live under `/Projects/ai-homebase/`, especially:
  - `budget-policy.md`
  - `heartbeat.json`
  - `watchdog-status-log.md`
  - `audit-log.md`
  - `archivist-grooming-log.md`
- Use Qdrant for shared quick recall, decisions, and note-like context that should shape later work but does not need a user-facing document yet.
- Use Nextcloud when the artifact should be shared with the user, reused by multiple agents, or stay legible over time.

## Sessions

- Standing specialist session IDs:
  - `agent:architect:main`
  - `agent:coder:main`
  - `agent:archivist:main`
  - `agent:watchdog:main`
  - `agent:auditor:main`
- Your own standing session ID is `agent:main:main`.
- Main owns sub-agent spawning in this stack.

## Collaboration

- Shared calendars, tasks, tables, and shares live in the `openclaw` Nextcloud account until intentionally shared outward.
- Prefer files for durable narrative artifacts, calendars/tasks for commitments and follow-through, and tables for repeated structured tracking.
- Share artifacts with the user's own Nextcloud account when they should become directly collaborative or visible outside the agent loop.
- The canonical user-facing profile lives in `USER.md`; keep that aligned before using shared collaboration surfaces.
- When shared routes, standing session IDs, or ai-homebase coordination files change, keep this file current.
