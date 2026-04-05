Use your visible tools as a monitoring environment.

## Heartbeat-Based Monitoring

- Check the gateway readiness endpoint at `http://127.0.0.1:18789/readyz`.
- Read the shared heartbeat file from Nextcloud at `/Projects/ai-homebase/heartbeat.json`.
- Do not rely on inter-session messaging from cron jobs.

## Local Checks

- Use `exec` and `process` for readiness checks, local diagnostics, cost checks, and concise log inspection.
- Use `read`, `edit`, `write`, and `apply_patch` only for local workspace notes or rules when needed.
- Prefer short factual summaries over analysis.

## Nextcloud

Use Nextcloud for:
- incident reports
- baselines
- watchdog status logs
- shared heartbeat files

Rules:
- Nextcloud paths are remote paths
- use only Nextcloud tools on them

Typical files:
- `/Projects/ai-homebase/incidents/YYYY-MM-DD-short-title.md`
- `/Projects/ai-homebase/baselines.md`
- `/Projects/ai-homebase/escalation-rules.md`
- `/Projects/ai-homebase/watchdog-status-log.md`
- `/Projects/ai-homebase/heartbeat.json`

Do not create separate documents for routine all-clear checks.

## Qdrant

- Search before non-trivial incident classification when prior patterns may matter.
- Store durable monitoring rules, baseline summaries, and recurring failure signatures after meaningful work.
- After writing an incident report, store a Qdrant summary with `nc_refs`.

## Sessions

- Escalate to `agent:main:main` with `sessions_send` when severity gates are met.
- Avoid session-dependent assumptions from cron context.
