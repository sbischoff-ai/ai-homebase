Check whether today had significant agent activity that warrants knowledge graph grooming.

Read the heartbeat file at `/Projects/ai-homebase/heartbeat.json` to see when main was last active. Check today's Codex usage log at `/Projects/ai-homebase/codex-usage/YYYY-MM-DD.json` (use today's date) for coder activity.

If any of these are true, send a grooming trigger to archivist via `sessions_send` to `agent:archivist:main`:
- Main's heartbeat shows activity in the last 12 hours with significant coordination (multiple agent handoffs logged)
- A Codex usage log exists for today with 3 or more entries
- You observed significant architect or coder activity during your heartbeat checks today

The grooming trigger message should be: "Nightly grooming triggered by watchdog. Today had significant activity. Run your standard grooming procedure per your workspace instructions."

If today was quiet, skip the trigger and just append a short note to `/Projects/ai-homebase/watchdog-status-log.md`: "YYYY-MM-DD 02:30 UTC -- activity check: quiet day, grooming skipped."

Keep this check fast and cheap. Do not read large files or search Qdrant -- just check the heartbeat and codex usage log.
