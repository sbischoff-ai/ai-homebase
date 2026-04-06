---
name: bootstrap_ops
description: Use when main is bootstrapping a fresh stack or re-aligning standing agents after setup drift. Covers first conversation capture, standing-session bring-up, shared Nextcloud structure, initial sharing, and durable bootstrap state.
---

# Bootstrap Ops

Use this skill only for first-run bootstrap or explicit stack re-alignment.

## Goals

- collect the minimum durable user facts
- confirm the standing specialists are reachable
- prepare the shared Nextcloud operating structure
- leave bootstrap state in durable systems, not just chat

## Procedure

1. Learn and record the user facts that bootstrap depends on:
   - what to call them
   - timezone
   - preferred tone
   - current priorities
   - desired assistant relationship
   - Nextcloud username
2. Update `USER.md` for main and propagate the same shared facts to the standing specialists.
3. Verify the standing specialist sessions respond:
   - `agent:architect:main`
   - `agent:coder:main`
   - `agent:archivist:main`
   - `agent:watchdog:main`
   - `agent:auditor:main`
4. Ensure Nextcloud has the shared bootstrap structure:
   - `/Projects/`
   - only the project folders immediately needed
5. Share `/Projects/` with the user's Nextcloud account during initial setup.
6. Tell the user that `/Projects/ai-homebase/budget-policy.md` is part of the shared project folder and is the place to review or change LLM budget policy.
7. Seed or update shared stack docs only when they are needed for immediate collaboration.
8. Store durable preferences in Qdrant.
9. Retire `BOOTSTRAP.md` only when first-run bootstrap is actually complete.

## Output

- synchronized `USER.md` files
- verified specialist availability
- shared `/Projects/` folder
- user informed about the shared budget policy file
- durable bootstrap facts in Qdrant and Nextcloud

## Boundaries

- Do not turn bootstrap into a generic checklist run.
- Do not create excessive top-level Nextcloud structure up front.
- Use `memory_and_heartbeat` for memory-trigger and heartbeat rules.
- Use `channel_binding` if bootstrap includes messaging setup.
