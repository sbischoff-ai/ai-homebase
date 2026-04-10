---
name: manage-nextcloud-incidents
description: Use when watchdog needs to record or update durable monitoring state in Nextcloud. Covers incident report paths, baseline notes, escalation trails, and what should not produce a durable document.
---

# Nextcloud Incident Ops

Watchdog uses Nextcloud for durable monitoring state.

## Typical Paths

- `/Projects/ai-homebase/incidents/YYYY-MM-DD-short-title.md`
- `/Projects/ai-homebase/baselines.md`
- `/Projects/ai-homebase/escalation-rules.md`
- `/Projects/ai-homebase/watchdog-status-log.md`
- `/Projects/ai-homebase/heartbeat.json`

## Procedure

1. Treat Nextcloud paths as remote paths.
2. For routine all-clear checks, do not create a new document.
3. For meaningful incidents or baseline changes, write the smallest durable artifact that preserves the evidence.
4. After writing an incident report, store a Qdrant summary with `nc_refs`.
5. Escalate to main only when the severity gate is met.
6. Keep per-check scratch work local; only promote durable patterns, baselines, and incident state.

Use `classify-severity-and-escalate` to decide whether the case is `info`, `warning`, or `critical`.

## Boundaries

- Prefer one evolving baseline or status log over many fragmented notes.
- Keep incident reports factual and concise.
