Check whether today had significant agent activity that warrants knowledge graph grooming.

Execution rules:
- Treat Nextcloud `/Projects/ai-homebase/heartbeat.json`, Nextcloud `/Projects/ai-homebase/codex-usage/YYYY-MM-DD.json`, and Nextcloud `/Projects/ai-homebase/watchdog-status-log.md` as Nextcloud remote paths, not local filesystem paths.
- Use only `nc_webdav_*` tools for those Nextcloud paths.
- Do not use shell commands, local file APIs, or workspace file tools on those Nextcloud paths.
- This cron prompt explicitly allows `sessions_send` only for the archivist grooming trigger described below.

Read the heartbeat file at Nextcloud `/Projects/ai-homebase/heartbeat.json` with an `nc_webdav_*` tool to see when main was last active. Check today's Codex usage log at Nextcloud `/Projects/ai-homebase/codex-usage/YYYY-MM-DD.json` (use today's date) with an `nc_webdav_*` tool for coder activity.

If any of these are true, send a grooming trigger to archivist via `sessions_send` to `agent:archivist:main`:
- Main's heartbeat shows activity in the last 12 hours
- A Codex usage log exists for today with 3 or more entries
- You observed significant architect or coder activity during your heartbeat checks today

The grooming trigger message should be: "Nightly grooming triggered by watchdog. Today had significant activity. Run your standard grooming procedure per your workspace instructions."

If today was quiet, skip the trigger and just append a short note to Nextcloud `/Projects/ai-homebase/watchdog-status-log.md` with an `nc_webdav_*` tool: "YYYY-MM-DD 02:30 UTC -- activity check: quiet day, grooming skipped."

Keep this check fast and cheap. Do not read large files or search Qdrant -- just check the heartbeat and codex usage log.
