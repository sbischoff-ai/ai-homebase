# Tools

Local notes for this setup.

## Files

- Files in this workspace are local workspace files.
- `CURRENT.md`, `SURFACES.md`, and `daily/` are your local desk. Read them at the start of every substantive session.
- Use local workspace files for private WIP, rough drafts, and self-management notes.
- `/Desk/...` are Nextcloud remote paths in the shared `openclaw` Nextcloud account for shared current state, recent briefings, and live indexing. They are separate from the user's own Nextcloud account.
- `/Projects/...` are Nextcloud remote paths owned by the shared `openclaw` Nextcloud account, which is separate from the user's own Nextcloud account.
- Shared ai-homebase files you will check often live under `/Projects/ai-homebase/`, especially:
  - `budget-policy.md`
  - `heartbeat.json`
  - `watchdog-status-log.md`
  - `audit-log.md`
  - `archivist-grooming-log.md`
- `TOOLS.md` keeps stable doctrine. Put volatile references and active surface lists in `SURFACES.md` and `/Desk/index.md` instead of bloating this file.
- Register important external surfaces in `/Desk/index.md` with:
  - `type`
  - stable `id` or path
  - purpose
  - steward agent
  - project slug or domain when relevant
  - read trigger such as `startup`, `heartbeat`, `active-project`, or `only-when-escalated`
- Use Qdrant for shared quick recall, decisions, and note-like context that should shape later work but does not need a user-facing document yet.
- Query Qdrant from the cues in `CURRENT.md`, `SURFACES.md`, and `/Desk/current.md`; do not treat startup as a blind memory dump.
- Ask archivist when the missing context is structural, cross-entity, or hard to recover through targeted semantic search.
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
- Register calendars, task lists, tables, user-shared folders, and other recurring Nextcloud surfaces in `/Desk/index.md` so later sessions can find them again.
- Prefer files for durable narrative artifacts, calendars/tasks for commitments and follow-through, and tables for repeated structured tracking.
- For startup review, default to looking back one day and ahead seven days on registered calendars or task lists unless the registered surface says otherwise.
- Share artifacts with the user's own Nextcloud account when they should become directly collaborative or visible outside the agent loop.
- The canonical user-facing profile lives in `USER.md`; keep that aligned before using shared collaboration surfaces.
- When shared routes, standing session IDs, or ai-homebase coordination files change, keep this file current.
