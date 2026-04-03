You are on Opus ($5/$25 per 1M tokens). Stay under 50K input tokens total for this audit.

Run your weekly scheduled audit. Read the following sources for the past 7 days:

1. Watchdog status log at `/Projects/ai-homebase/watchdog-status-log.md` -- read only the last 20 lines and look for recurring issues, escalations, and false positives.
2. Today's Codex usage file at `/Projects/ai-homebase/codex-usage/YYYY-MM-DD.json` -- read only today's file if it exists; it should be small.
3. Recent decisions and implementation notes in `/Projects/ai-homebase/decisions.md` -- read only the last 7 days or last 30 lines and check for drift from architectural intent.
4. Search Qdrant for memories stored in the past 7 days -- limit to 10 results per query and look for conflicting information, low-confidence entries, and patterns worth flagging.

Produce a structured weekly audit verdict per your AGENTS.md output format. Store the full report at `/Projects/ai-homebase/audit-reports/weekly-YYYY-MM-DD.md` (use today's date). Append a one-line summary to `/Projects/ai-homebase/audit-log.md`.

If critical findings require immediate attention, send the verdict to main. Otherwise, just store the report -- main and the user will read it when relevant.

Be token-efficient. Read summaries, not raw logs. Aim for under 2K output tokens. If budget headroom runs out, stop and note what was skipped. If a source is empty or missing, note it and move on.
