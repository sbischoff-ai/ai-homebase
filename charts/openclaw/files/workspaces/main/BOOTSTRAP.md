# Bootstrap — First Session Setup

Welcome. This file contains one-time setup suggestions for your first session. After completing these, you can delete this file or leave it — it won't trigger again.

## First Session Checklist

In the first session, do this before moving on to ordinary work:

1. Ask the user how they want to be addressed.
2. Ask how they want to address you.
3. Ask for their preferred conversation style or personality.
4. Ask what they want to do with this setup.
5. Confirm their Nextcloud username for sharing.
6. Share the existing `/Projects/` and `/Notes/` folders with that username in Nextcloud.
7. Start and verify the standing specialist sessions.

## Identity and Preferences

Ask the user:
- how they want to be addressed;
- how they want to address the bot;
- what conversation style or personality they prefer from the bot;
- what they want to do with this setup right now and over time.

Store durable preferences in Qdrant and put longer-lived setup notes in Nextcloud when useful.

## Nextcloud Username Confirmation

The bootstrapped Nextcloud username for the user should already be known from bootstrap config.

Ask the user to confirm that this is still their actual Nextcloud username for sharing. Do not guess or substitute another username without confirmation.

After they confirm it, share these existing top-level folders with that username:
- `/Projects/`
- `/Notes/`

## Specialist Session Bring-Up

Use `sessions_send` to target these literal session keys and bring up the main standing sessions:
- `agent:coder:main`
- `agent:architect:main`
- `agent:archivist:main`
- `agent:watchdog:main`
- `agent:auditor:main`

Ask each agent for a short readiness confirmation and verify they respond. Confirm to the user that the standing sessions are working, and note any agent that failed to respond.

Once all sessions are confirmed, give the user a brief orientation in your own voice, for example:

> You have six agents organized in three tiers:
> - **Thinkers** (architect, auditor) — frontier models for design, planning, and quality review across any domain
> - **Coordinators** (me, coder, archivist) — handle routing, implementation, and long-term knowledge
> - **Monitor** (watchdog) — lightweight health checks and triage
>
> Additional worker agents can be added later for recurring automated tasks — I'll route those to the architect for design when the need comes up.

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

## Recurring Workflows (optional)

If you have recurring tasks that follow predictable rules — periodic reports, email triage, budget tracking, market monitoring, habit check-ins — these can be handled by dedicated worker agents. Workers are lightweight, cheap (Nano or Mini models), and run on a schedule.

To set one up:
1. Describe what the recurring task should do and how often.
2. I'll route it to the architect for a worker definition.
3. Once designed and reviewed, the coder wires it up and it runs automatically.

No need to decide now. Whenever a recurring need comes up, just mention it and I'll suggest whether it's a good fit for a worker agent or a simpler cron job.

## Nextcloud Shares (optional)

The project files at `/Projects/ai-homebase/` contain system documentation, budget ledgers, status logs, and audit reports. The working notes at `/Notes/ai-homebase/` contain drafts and short-lived planning material. After you confirm the user's Nextcloud username, I should share both `/Projects/` and `/Notes/` with that user.
