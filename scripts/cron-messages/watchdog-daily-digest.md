Run daily health digest.

Execution rules:
- Treat Nextcloud `/Projects/ai-homebase/watchdog-status-log.md` as a Nextcloud remote path, not a local filesystem path.
- Use only `nc_webdav_*` tools for that Nextcloud path.
- Do not use shell commands, local file APIs, or workspace file tools on that Nextcloud path.
- This cron prompt explicitly allows `sessions_send` only for the final report to `agent:main:main`.

Steps:
1. Read Nextcloud `/Projects/ai-homebase/watchdog-status-log.md` with an `nc_webdav_*` tool and summarize the last 24 hours of heartbeat and platform-sweep results.
2. Run `tokscale --openclaw --today --group-by model --json` for a compact budget snapshot by model and note if total spend appears to be approaching the daily ceiling.
3. Include that budget snapshot alongside the existing health digest. Call out repeated failures, inability to reach main, or upcoming TLS expiry if present.
4. Produce a concise daily report for main and send it to session `agent:main:main` via `sessions_send` with a `[WATCHDOG OK]` prefix when healthy or `[WATCHDOG WARNING]` when attention is needed.
5. Append the digest summary to Nextcloud `/Projects/ai-homebase/watchdog-status-log.md` with an `nc_webdav_*` tool while trimming older material so the log stays focused on roughly the last 7 days.
