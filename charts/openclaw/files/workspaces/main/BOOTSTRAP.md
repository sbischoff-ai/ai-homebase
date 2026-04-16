# Bootstrap

Fresh stack bootstrap is a conversation first, then a stack-alignment task.

Do not run a sterile checklist. Talk naturally, but make sure the whole multi-agent stack becomes usable.

## First Conversation

Learn enough to anchor the system:
- what to call the user and what they should call you
- timezone
- preferred tone
- current priorities
- what kind of assistant relationship they want
- Nextcloud username

Then update:
- your `USER.md`
- each standing specialist's `USER.md` with the same shared user facts
- your `IDENTITY.md` only if the user meaningfully changes how they want you to present yourself

## Bring Up The Stack

After the basic introduction:
1. Verify the standing specialist sessions respond:
   - `agent:architect:main`
   - `agent:coder:main`
   - `agent:archivist:main`
   - `agent:watchdog:main`
   - `agent:auditor:main`
2. Ensure shared Nextcloud structure exists:
   - Nextcloud `/Projects/`
   - Nextcloud `/Desk/` if shared continuity is needed now
   - Nextcloud `/Desk/current.md` if Nextcloud `/Desk/` is being used
   - Nextcloud `/Desk/index.md` if Nextcloud `/Desk/` is being used
   - Nextcloud `/Desk/daily/README.md` if Nextcloud `/Desk/daily/` is being used
   - project folders bootstrap depends on
3. Share Nextcloud `/Projects/` with the user's Nextcloud account during initial setup.
4. Create the Nextcloud `/Desk/` surfaces on first use instead of assuming they already exist.
5. Keep Nextcloud `/Desk/` inside the shared `openclaw` account unless a specific continuity artifact should be shared outward.
6. Create additional Nextcloud folders only when the work benefits from them.
7. Seed or update any shared stack docs needed for immediate collaboration and continuity.

## Explain The System Briefly

Give the user a short orientation:
- you are the coordinator
- architect designs
- coder implements
- archivist maintains durable knowledge and the graph
- watchdog monitors and triages
- auditor reviews
- workers can be added later for recurring workflows
- Nextcloud `/Projects/ai-homebase/budget-policy.md` is shared with them and is the user-visible place to review or change LLM budget policy

## Channels

Ask how they want to reach you:
- just here
- Telegram, WhatsApp, Signal, Discord, or another bound channel

If channel setup is needed, use the `bind-channels` skill and follow its binding rules.

Once the primary channel is set, ask whether they want a dedicated agent channel. Architect is the usual first candidate.

## Optional Shared Ops Setup

If the user wants operational help immediately, set up:
- calendar collaboration
- todos
- lightweight tables for tracking projects or recurring work
- daily or periodic briefings via cron

Register recurring calendars, task lists, tables, and any user-shared folders in Nextcloud `/Desk/index.md` so later sessions can find them again, but only after that shared index exists.

## Finish

Store durable preferences in Qdrant.
Store shared short-term continuity in Nextcloud `/Desk/`.
Store durable collaboration artifacts in Nextcloud.
Delete `BOOTSTRAP.md` only when bootstrap is complete and the standing workspace can orient without it.
