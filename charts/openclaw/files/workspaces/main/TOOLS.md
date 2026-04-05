Use your visible tools as your operating environment.

## Local Workspace

- Use `read`, `edit`, `write`, and `apply_patch` for local workspace files.
- Use `exec` and `process` for shell commands, automation, and local inspection.
- Use `browser`, `web_search`, and `web_fetch` when the task needs current web context.

## Nextcloud

The `openclaw` Nextcloud account is part of your normal operating space, not just a file dump.

Use Nextcloud tools for:
- `/Projects/...` files
- calendar events and todos
- tables that track ongoing work
- shares with the user
- any additional Nextcloud folders the agents intentionally create

Rules:
- treat Nextcloud paths as remote paths
- never use local file tools or shell path assumptions on those paths
- create missing parent directories with Nextcloud tools before writing

Default uses:
- `/Projects/<slug>/`: stable project docs, plans, decisions, status, user-visible outputs
- calendar: deadlines, reminders, recurring coordination
- tables: structured trackers when a flat markdown file is no longer enough
- shares: expose durable folders or artifacts to the user

Initial sharing rule:
- share `/Projects/` by default
- do not assume any other top-level Nextcloud folder exists or is shared until you create it intentionally

## Qdrant

- Use `qdrant-find` before non-trivial coordination when prior context may matter.
- Use `qdrant-store` for durable preferences, decisions, and stack rules.
- When a memory points to a Nextcloud artifact, include `nc_refs`.

## Sessions

- Use `sessions_send` for specialist handoffs and result collection.
- Use `sessions_spawn` only when bringing up new isolated sessions or workers.
- Use `session_status` or `sessions_list` when you need to inspect live session state.

## Budget And Cost

- Use `exec` for local cost and runtime commands such as `tokscale`.
- Codex usage is tracked in Nextcloud by coder at `/Projects/ai-homebase/codex-usage/YYYY-MM-DD.json`.
- Toksale on the gateway does not include sandbox Codex usage by itself. Read both surfaces when you need a full total.

## Default Discipline

- Prefer specialized tools over generic shell work when a specialized tool exists.
- Prefer writing durable shared state once to Nextcloud over repeating it in long inter-agent messages.
