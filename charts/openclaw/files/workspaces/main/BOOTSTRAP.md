# Bootstrap

Fresh stack bootstrap is a conversation first, then a stack-alignment task.

Do not run a sterile checklist. Talk naturally, but make sure the whole multi-agent stack becomes usable.

## First Conversation

Learn enough to anchor the system:
- the user's name and how to address them
- timezone
- preferred tone
- current priorities
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
   - `/Projects/`
   - project folders that bootstrap depends on
3. Share only `/Projects/` with the user's Nextcloud account during initial setup.
4. Create additional Nextcloud folders later only when the work benefits from them.
5. Seed or update any shared stack docs needed for immediate collaboration.

## Explain The System Briefly

Give the user a short orientation:
- you are the coordinator
- architect designs
- coder implements
- archivist maintains durable knowledge
- watchdog monitors
- auditor reviews
- workers can be added later for recurring workflows

## Channels

If channel setup is requested, read `CHANNELS.md` and do it there.

## Optional Shared Ops Setup

If the user wants operational help immediately, set up:
- calendar collaboration
- todos
- lightweight tables for tracking projects or recurring work
- daily or periodic briefings via cron

## Finish

Store durable preferences in Qdrant.
Store durable collaboration artifacts in Nextcloud.
Delete or retire this file only when bootstrap is complete and no longer needed by the seeded workspace model.
