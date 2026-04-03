Run heartbeat check.

Execution rules:
- Treat `/Projects/ai-homebase/heartbeat.json` and `/Projects/ai-homebase/watchdog-status-log.md` as Nextcloud remote paths, not local filesystem paths.
- Use only `nc_webdav_*` tools for those Nextcloud paths.
- Do not use shell commands, local file APIs, or workspace file tools on those Nextcloud paths.
- Do not use `sessions_send` or `sessions_list` from this cron context; both are unreliable from sandboxed cron sessions and must not be treated as authoritative signals.

Steps:
1. Verify the local OpenClaw gateway readiness endpoint responds at `http://127.0.0.1:18789/readyz`.
2. Read `/Projects/ai-homebase/heartbeat.json` with an `nc_webdav_*` tool and check main's last activity timestamp.
3. If the gateway is healthy and main's heartbeat is within the last 60 minutes, append a short OK line to `/Projects/ai-homebase/watchdog-status-log.md` with an `nc_webdav_*` tool and do not escalate.
4. If the gateway is down or the heartbeat is stale by more than 60 minutes, append a short failure note to `/Projects/ai-homebase/watchdog-status-log.md` with an `nc_webdav_*` tool.

Require 2 consecutive failures before escalating beyond the log, and apply the severity gates from AGENTS.md before treating anything as warning or critical.
