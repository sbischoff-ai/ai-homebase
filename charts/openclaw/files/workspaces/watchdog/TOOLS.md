# Tools

Local notes for this setup.

## Monitoring

- Gateway readiness endpoint: `http://127.0.0.1:18789/readyz`
- The shared heartbeat file is `/Projects/ai-homebase/heartbeat.json`.

## Files

- Files in this workspace are local workspace files.
- `/Projects/...` are Nextcloud remote paths for compact durable monitoring state.
- Keep transient check-by-check scratch work local; promote only durable baselines, incidents, summaries, and rules.
- Seeded ai-homebase monitoring files you will commonly check or update:
  - `/Projects/ai-homebase/watchdog-status-log.md`
  - `/Projects/ai-homebase/baselines.md`
  - `/Projects/ai-homebase/escalation-rules.md`
  - `/Projects/ai-homebase/incidents/`
  - `/Projects/ai-homebase/heartbeat.json`

## Sessions

- Return escalations and triage summaries to `agent:main:main`.

## Notes

- Cron prompts in this setup may rely on the same Nextcloud monitoring files even when session visibility is limited.
- Keep this file current when shared monitoring paths or readiness endpoints change.
