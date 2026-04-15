---
name: manage-worker-lifecycle
description: Use when deciding whether recurring work should become a worker, or when requesting, activating, updating, or retiring a worker.
---

# Worker Lifecycle

Use when recurring work might become a worker.

## Decision Rule

- If a recurring task is a simple timed check, polling loop, or reminder, prefer `watchdog` or a conservative cron before involving a higher-cost specialist.
- If it is a recurring multi-step workflow with stable rules, route to architect for a worker definition.
- If the workflow truly needs heartbeat, treat that as a strong signal for a dedicated worker on `gpt-5.4-nano` unless the task clearly needs `gpt-5.4-mini`.
- Do not give a frontier standing agent a default heartbeat unless the user is explicitly aware of the ongoing budget cost.

## Requesting A Worker Definition

When asking architect for a worker, include:
- what it should do
- how often it should run
- what tools or data sources it needs
- any sensitivity concerns

## Activating An Approved Worker

1. Read the approved package from a Nextcloud remote path.
2. Create the workspace directory.
3. Fill the worker-template files, including `CURRENT.md`, `SURFACES.md`, and `daily/` when the worker should keep continuity across sessions.
4. Register the agent with `openclaw agents add`.
5. Update Nextcloud `/Projects/ai-homebase/budget-policy.md` if the new agent changes the stack's ongoing LLM spend posture, expected daily budget, or token guidance.
6. Register any shared worker surfaces in Nextcloud `/Desk/index.md` when they will matter outside the worker's private workspace.
7. Add cron if needed.
8. Confirm activation to the user.

## Worker Lifecycle Rules

- when agents are added, retired, or materially re-scoped, keep Nextcloud `/Projects/ai-homebase/budget-policy.md` current if budget posture changes
- updates go through architect first
- create `HEARTBEAT.md` only when the approved worker definition explicitly uses heartbeat; otherwise use cron or on-demand triggers only
- decommission by removing cron, deleting the agent, and informing the user

## Boundaries

- Main owns instantiation, scheduling, and retirement after approval.
- Main also owns keeping the shared budget policy aligned with live agent changes it makes.
- Do not skip architect when the workflow needs a real worker definition.
