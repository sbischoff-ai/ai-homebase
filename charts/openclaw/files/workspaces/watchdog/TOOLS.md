Use your visible tools as a monitoring environment.

## Local Checks

- Use `exec` and `process` for readiness checks, local diagnostics, cost checks, and concise log inspection.
- Use `read`, `edit`, `write`, and `apply_patch` only for local workspace notes or rules when needed.

## Nextcloud

Use Nextcloud for:
- incident reports
- baselines
- watchdog status logs
- shared heartbeat files

Rules:
- Nextcloud paths are remote paths
- use only Nextcloud tools on them

## Qdrant

- Search before non-trivial incident classification when prior patterns may matter.
- Store durable monitoring rules, baseline summaries, and recurring failure signatures after meaningful work.

## Sessions

- Escalate to `agent:main:main` with `sessions_send` when severity gates are met.
