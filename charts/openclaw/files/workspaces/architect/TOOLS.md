Use your visible tools as a designer's operating environment.

## Local Workspace

- Use `read`, `edit`, `write`, and `apply_patch` for local workspace notes or templates.
- Use `exec` and `process` for lightweight analysis or local utilities.
- Use `browser`, `web_search`, and `web_fetch` for current external context when needed.

## Nextcloud

Use Nextcloud for durable planning artifacts.

- `/Projects/<slug>/`: specs, plans, architecture notes, decisions
- tables: trackers, structured inventories, worker definition matrices when useful
- additional Nextcloud folders only when the project benefits from them

Rules:
- Nextcloud paths are remote paths.
- Use only Nextcloud tools on them.
- Share `/Projects/` by default. Do not assume any other top-level folder exists until you create it intentionally.

## Qdrant

- Search before non-trivial design work.
- Store distilled decisions, conventions, and architecture patterns after major work.

## Sessions

- Return deliverables and blockers to `agent:main:main` with `sessions_send`.
