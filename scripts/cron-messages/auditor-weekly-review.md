You are on Opus ($5/$25 per 1M tokens). Stay under 50K input tokens total for this audit.

Run your weekly scheduled audit. Read the following sources for the past 7 days:

Execution rules:
- Treat every `/Projects/...` path below as a Nextcloud remote path, not a local filesystem path.
- Use only `nc_webdav_*` tools for those Nextcloud paths.
- Do not use shell commands, local file APIs, or workspace file tools on those Nextcloud paths.

1. Watchdog status log at `/Projects/ai-homebase/watchdog-status-log.md` -- read only the last 20 lines and look for recurring issues, escalations, false positives, and recurring toil.
2. Audit log at `/Projects/ai-homebase/audit-log.md` -- read only the recent entries so you can compare this week's findings against prior audits.
3. Codex usage files under `/Projects/ai-homebase/codex-usage/` for the past 7 days -- read only files that exist and summarize trends rather than copying details.
4. Recent decisions and implementation notes in `/Projects/ai-homebase/decisions.md` -- read only the last 7 days or last 30 lines and check for drift from architectural intent.
5. Automation backlog at `/Projects/ai-homebase/automation-backlog.md` -- read the last 20 lines to avoid repeating stale proposals.
6. Search Qdrant for memories stored in the past 7 days -- limit to 10 results per query and look for conflicting information, low-confidence entries, repeated friction, and patterns worth turning into deterministic workflows.

Produce a structured weekly audit verdict per your AGENTS.md output format.

Your `Improvement Opportunities` section is mandatory. It must include concrete proposals in these categories when evidence exists:
- prompt/workspace/documentation refinement
- model-routing or budget optimization
- workflow automation candidate
- deterministic replacement candidate as a Kubernetes `CronJob`, long-running `Service`, or controller/helper

Store the full report at `/Projects/ai-homebase/audit-reports/weekly-YYYY-MM-DD.md` (use today's date) with an `nc_webdav_*` tool. Append a one-line summary to `/Projects/ai-homebase/audit-log.md` with an `nc_webdav_*` tool. Append concise actionable proposals to `/Projects/ai-homebase/automation-backlog.md` with an `nc_webdav_*` tool so architect and coder can pick them up later.

If critical findings require immediate attention, send the verdict to main. Otherwise, just store the report -- main and the user will read it when relevant.

Ownership rule:
- you propose improvements;
- architect specifies accepted changes;
- coder implements accepted repo, image, automation, or GitOps work.

Be token-efficient. Read summaries, not raw logs. Aim for under 2K output tokens. If budget headroom runs out, stop and note what was skipped. If a source is empty or missing, note it and move on.
