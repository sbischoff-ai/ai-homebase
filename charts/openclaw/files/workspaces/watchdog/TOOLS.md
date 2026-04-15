# Tools

This file records how this OpenClaw setup expects you to use your available tools and skills. It distinguishes local workspace files from remote Nextcloud paths where that matters.

## Monitoring

- Gateway readiness endpoint: `http://127.0.0.1:18789/readyz`
- The shared coordination status marker is Nextcloud `/Projects/ai-homebase/coordination-status.json`.

## Files

- Files in this workspace are local workspace files.
- `CURRENT.md`, `SURFACES.md`, and `daily/` are custom local continuity surfaces for active monitoring work.
- Nextcloud `/Desk/...` are remote paths for shared current-state briefings and live indexing. Read only the entries relevant to coordination status, orientation work, or active incidents.
- Nextcloud `/Projects/...` are remote paths for compact durable monitoring state.
- Use local workspace file tools only for local workspace files such as `CURRENT.md`, `SURFACES.md`, `daily/`, and other files in this workspace.
- Use Nextcloud tools only for Nextcloud `/Desk/...` and Nextcloud `/Projects/...` paths.
- Do not create or edit a local file and expect it to appear in Nextcloud.
- Do not create or edit a Nextcloud file and expect it to appear in this local workspace.
- Do not create a local directory and expect it to exist in Nextcloud, or create a Nextcloud directory and expect it to exist locally.
- Do not use local filesystem tools on Nextcloud paths, and do not use Nextcloud tools on local workspace files.
- Keep transient check-by-check scratch work local; promote only durable baselines, incidents, summaries, and rules.
- Keep `TOOLS.md` stable. Put active surface references in `SURFACES.md` and shared non-project registrations in Nextcloud `/Desk/index.md`.
- ai-homebase monitoring files you will commonly check or update:
  - Nextcloud `/Projects/ai-homebase/watchdog-status-log.md`
  - Nextcloud `/Projects/ai-homebase/baselines.md`
  - Nextcloud `/Projects/ai-homebase/escalation-rules.md`
  - Nextcloud `/Projects/ai-homebase/incidents/`
  - Nextcloud `/Projects/ai-homebase/coordination-status.json`

## Sessions

- Return escalations and triage summaries to `agent:main:main`.

## Notes

- Cron prompts may rely on the same Nextcloud monitoring files even when session visibility is limited.
- If you create or discover a recurring shared monitoring surface outside Nextcloud `/Projects/ai-homebase/`, register it in Nextcloud `/Desk/index.md` with steward and read trigger metadata.
- Keep this file current when shared monitoring paths or readiness endpoints change.
