Run platform sweep.

Execution rules:
- Treat `/Projects/ai-homebase/watchdog-status-log.md` as a Nextcloud remote path, not a local filesystem path.
- Use only `nc_webdav_*` tools for that Nextcloud path.
- Do not use shell commands, local file APIs, or workspace file tools on that Nextcloud path.
- Do not use `sessions_send` or `sessions_list` from this cron context; they are unreliable here and must not be used as the escalation path.

Steps:
1. Check the local OpenClaw gateway readiness endpoint.
2. Inspect recent session behavior with the `session-logs` skill when that helps confirm whether failures are transient or recurring.
3. Inspect TLS expiry for the core ingress hosts you can reach from the gateway with `openssl`, including OpenClaw and the MCP endpoints.
4. Summarize findings concisely and append the result to `/Projects/ai-homebase/watchdog-status-log.md` with an `nc_webdav_*` tool.

If issues are found, write a clear warning or critical note to that Nextcloud status log and explicitly flag it for main to pick up from the log. If everything is clear, append a one-line all-clear and do not escalate.
