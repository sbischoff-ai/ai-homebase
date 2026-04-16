Check whether today had significant agent activity that warrants knowledge graph grooming.

Execution rules:
- Treat Nextcloud `/Projects/ai-homebase/coordination-status.json`, Nextcloud `/Projects/ai-homebase/codex-usage/YYYY-MM-DD.json`, Nextcloud `/Projects/ai-homebase/watchdog-status-log.md`, and Nextcloud `/Desk/index.md` as Nextcloud remote paths, not local filesystem paths.
- Use only `nc_webdav_*` tools for those Nextcloud paths.
- Do not use shell commands, local file APIs, or workspace file tools on those Nextcloud paths.
- No human reads a normal reply in this cron session. Do the check, write the durable result, send the allowed escalation only when it is warranted, and then stop.
- This cron prompt explicitly allows `sessions_send` only for the archivist grooming trigger described below.

Read the coordination status marker at Nextcloud `/Projects/ai-homebase/coordination-status.json` with an `nc_webdav_*` tool to see when main last recorded meaningful shared coordination activity. Check today's Codex usage log at Nextcloud `/Projects/ai-homebase/codex-usage/YYYY-MM-DD.json` (use today's date) with an `nc_webdav_*` tool for coder activity if that file exists. If cheap WebDAV metadata is available and Nextcloud `/Desk/index.md` exists, inspect it and the registered high-value surfaces named there for modified time, etag, and size. Use the window since the previous `activity check:` line in Nextcloud `/Projects/ai-homebase/watchdog-status-log.md`; if there is no prior line, use the last 24 hours. Read only compact status summaries and metadata; do not read large content bodies.

Use this score model:
- `main_coordination_status_recent`: +1 when `coordination-status.json` has `lastActivity` within the last 12 hours.
- `codex_usage_notable`: +2 when today's Codex usage log has 3 or more entries, or when one entry is unusually large or costly based on fields available in the log.
- `sessions_notable`: +2 when a compact session summary shows 2 or more non-watchdog sessions, one lengthy brainstorming session, or architect/coder activity.
- `nextcloud_changes_notable`: +2 when WebDAV metadata shows 3 or more registered surfaces modified within the activity window, or any registered surface modified within the activity window is at least 10KB. Only claim size growth when previous size metadata is available in a prior status-log note; otherwise say "large modified surface", not "grew".
- `system_change_notable`: +2 when the recent watchdog status log mentions deploy, GitOps, image, schema, service, Qdrant, Memgraph, OpenClaw, warning, or critical changes.

Send a grooming trigger to archivist via `sessions_send` to `agent:archivist:main` only when the score is 3 or higher, or when a critical system-change signal appears. The coordination status marker by itself is not enough to trigger grooming.

The grooming trigger message should be:
`Nightly graph grooming triggered by watchdog. Window: <start>..<end>. Reasons: <reason codes>. Metrics: <compact metrics>. Run delta grooming from your checkpoint and append the grooming log.`

Always append a short decision note to Nextcloud `/Projects/ai-homebase/watchdog-status-log.md` with an `nc_webdav_*` tool:
`YYYY-MM-DD 02:30 UTC -- activity check: score=<n> reasons=<reason codes> action=<triggered|skipped>.`

Keep this check fast and cheap. Do not search Qdrant or perform Memgraph/Qdrant grooming work yourself.
