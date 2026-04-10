Deliver the morning brief to the user. Summarize concisely:

Execution rules:
- Treat every `Nextcloud /Projects/...` path below as a Nextcloud remote path, not a local filesystem path.
- Use only `nc_webdav_*` tools for those Nextcloud paths.
- Do not use shell commands, local file APIs, or workspace file tools on those Nextcloud paths.

1. **Overnight activity:** Check Nextcloud `/Projects/ai-homebase/watchdog-status-log.md` (last 10 lines) and Nextcloud `/Projects/ai-homebase/archivist-grooming-log.md` (last entry) for overnight agent activity. Check Nextcloud `/Projects/ai-homebase/audit-log.md` for any recent auditor findings.

2. **Budget status:** Run `tokscale --openclaw --today --json`, `tokscale --openclaw --week --json`, and `tokscale --openclaw --month --json`. Also read today's Codex usage file at Nextcloud `/Projects/ai-homebase/codex-usage/YYYY-MM-DD.json` if it exists. Summarize today's spend so far, this week's total, and this month's total against the $15/$50/$150 ceilings.

3. **Pending items:** Search Qdrant for recent memories tagged `[task-context]` or `[incident]` that may need user attention. Check if any agent handoffs are waiting for user input.

4. **Calendar:** If a shared calendar exists, list today's events.

Keep the brief under 300 words. Use bullet points. If everything is quiet, just say so — don't pad.
