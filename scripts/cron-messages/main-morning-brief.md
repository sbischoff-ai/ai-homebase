Deliver the morning brief to the user. Summarize concisely:

1. **Overnight activity:** Check `/Projects/ai-homebase/watchdog-status-log.md` (last 10 lines) and `/Projects/ai-homebase/archivist-grooming-log.md` (last entry) for overnight agent activity. Check `/Projects/ai-homebase/audit-log.md` for any recent auditor findings.

2. **Budget status:** Read `/Projects/ai-homebase/budget-ledger.json`. Summarize today's spend so far, this week's total, and this month's total against the $15/$50/$150 ceilings.

3. **Pending items:** Search Qdrant for recent memories tagged `[task-context]` or `[incident]` that may need user attention. Check if any agent handoffs are waiting for user input.

4. **Calendar:** If a shared calendar exists, list today's events.

Keep the brief under 300 words. Use bullet points. If everything is quiet, just say so — don't pad.
