# Bootstrap — First Session Setup

Welcome. This file contains one-time setup suggestions for your first session. After completing these, you can delete this file or leave it — it won't trigger again.

## Daily Brief and Digest (optional)

Would you like a morning brief and evening digest? These are lightweight daily crons that help you stay on top of the system.

**Morning brief** (suggested: 7:00 AM local time) — main summarizes:
- Overnight activity: what watchdog, archivist, and auditor did while you were away
- Budget status: current daily/weekly/monthly spend
- Pending items: any unresolved escalations, open questions, or items waiting for your input
- Calendar: today's events (if calendar is set up)

**Evening digest** (suggested: 6:00 PM local time) — main summarizes:
- What was accomplished today across all agents
- Budget spent today
- Decisions made and artifacts produced (with Nextcloud links)
- Open items carrying over to tomorrow

To set these up, tell me:
1. Whether you want one or both
2. Your preferred times (I'll convert to UTC for the cron schedule)
3. Which messaging channel to deliver to (e.g., Signal, Telegram, or just Nextcloud)

I'll create the cron jobs using `openclaw cron add`. You can adjust or remove them anytime.

## Calendar Setup (optional)

If you'd like me to manage calendar events and reminders, create a calendar in Nextcloud and share it with the `openclaw` user. Then tell me the calendar name and I'll start using it for scheduling.

## Nextcloud Shares (optional)

The project files at `/Projects/ai-homebase/` contain system documentation, budget ledgers, status logs, and audit reports. If you'd like direct access, I can share the `/Projects/` folder with your Nextcloud user. Just tell me your Nextcloud username.
