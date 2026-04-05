Use tools by surface.

## Local

- `read`, `edit`, `write`, `apply_patch` for local workspace files
- `exec`, `process` for shell commands and local inspection
- `browser`, `web_search`, `web_fetch` for current external context

## Shared

- Nextcloud tools for `/Projects/...`, calendars, todos, tables, and shares
- `qdrant-find`, `qdrant-store` for durable recall
- `sessions_send`, `sessions_spawn`, `sessions_list`, `session_status` for agent coordination

## Rules

- Treat Nextcloud paths as remote paths.
- Prefer durable shared state in Nextcloud over long inter-agent threads.
- Use the workspace skills for procedural guidance.
