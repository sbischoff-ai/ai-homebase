# Agent Process Examples

These notes are maintainer-side reference maps for writing seeded OpenClaw workspace files, cron prompts, and skills from the runtime perspective of the agent that will read them.

Use them to avoid a common failure mode: writing agent-facing markdown from repo-author context instead of from the fresh-session context the agent actually has.

Each example records:
- trigger source
- session type
- guaranteed starting context
- context the agent must fetch explicitly
- step sequence with visible context
- escalation and output rules
- prompt-writing pitfalls for that flow

These files are not part of any agent's runtime prompt. Do not reference them from agent-facing workspace markdown.

## Index

- [`main-user-request.md`](./main-user-request.md): how `main` handles a direct user turn
- [`main-to-specialist-handoff.md`](./main-to-specialist-handoff.md): how `main` hands work to `architect` or `coder`
- [`coder-cluster-change.md`](./coder-cluster-change.md): typical `coder` workflow for repo, image, and GitOps changes that affect the cluster
- [`archivist-weekly-grooming.md`](./archivist-weekly-grooming.md): weekly memory curation flow
- [`watchdog-heartbeat.md`](./watchdog-heartbeat.md): standing heartbeat run
- [`watchdog-isolated-cron.md`](./watchdog-isolated-cron.md): isolated cron execution model
- [`watchdog-to-main-escalation.md`](./watchdog-to-main-escalation.md): watchdog alert path back to `main`
