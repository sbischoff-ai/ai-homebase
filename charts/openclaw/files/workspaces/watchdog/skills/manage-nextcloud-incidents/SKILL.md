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
4. Update `/Desk/current.md` or `/Desk/daily/` when another session should be aware of an active or recent incident quickly.
5. If you create a recurring shared monitoring surface outside the usual incident paths, register it in `/Desk/index.md`.
6. After writing an incident report, store a Qdrant summary with `project`, `tags`, and `nc_refs`.
7. Escalate to main only when the severity gate is met.
8. Keep per-check scratch work local; only promote durable patterns, baselines, and incident state.

Use `classify-severity-and-escalate` to decide whether the case is `info`, `warning`, or `critical`.

## Boundaries

- Prefer one evolving baseline or status log over many fragmented notes.
- Do not turn `/Desk/` into an incident archive; it is for bounded continuity.
- Keep incident reports factual and concise.
