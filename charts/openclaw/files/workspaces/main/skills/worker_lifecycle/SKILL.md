---
name: worker_lifecycle
description: Use when main needs to decide whether a worker is appropriate, request a worker definition from architect, instantiate an approved worker, or retire one. Covers worker-definition inputs, activation steps, update flow, and decommissioning.
---

# Worker Lifecycle

Use this skill when recurring work might become a worker.

## Decision Rule

- If a recurring task is a simple timed check or reminder, prefer a cron in main or watchdog.
- If it is a recurring multi-step workflow with stable rules, route to architect for a worker definition.

## Requesting A Worker Definition

When asking architect for a worker, include:
- what it should do
- how often it should run
- what tools or data sources it needs
- any sensitivity concerns

## Activating An Approved Worker

1. Read the package from Nextcloud.
2. Create the workspace directory.
3. Fill the worker-template files.
4. Register the agent with `openclaw agents add`.
5. Add cron if needed.
6. Confirm activation to the user.

## Worker Lifecycle Rules

- updates go through architect first
- decommission by removing cron, deleting the agent, and informing the user

## Boundaries

- Main owns instantiation, scheduling, and retirement after approval.
- Do not skip architect when the workflow needs a real worker definition.
