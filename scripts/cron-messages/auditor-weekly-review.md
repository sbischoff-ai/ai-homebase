Run your weekly scheduled audit. Read the following sources for the past 7 days:

1. Watchdog status log at `/Projects/ai-homebase/watchdog-status-log.md` -- look for recurring issues, escalations, and false positives.
2. Budget ledger at `/Projects/ai-homebase/budget-ledger.json` -- check for cost anomalies, agents exceeding soft budgets, and total spend trajectory.
3. Recent decisions and implementation notes in `/Projects/ai-homebase/decisions.md` -- check for drift from architectural intent.
4. Search Qdrant for memories stored in the past 7 days -- look for conflicting information, low-confidence entries, and patterns worth flagging.

Produce a structured weekly audit verdict per your AGENTS.md output format. Store the full report at `/Projects/ai-homebase/audit-reports/weekly-YYYY-MM-DD.md` (use today's date). Append a one-line summary to `/Projects/ai-homebase/audit-log.md`.

If critical findings require immediate attention, send the verdict to main. Otherwise, just store the report -- main and the user will read it when relevant.

Be token-efficient. Read summaries, not raw logs. If a source is empty or missing, note it and move on.
