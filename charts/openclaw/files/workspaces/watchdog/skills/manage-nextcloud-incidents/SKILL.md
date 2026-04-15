---
name: manage-nextcloud-incidents
description: Use when recording or updating durable monitoring state in Nextcloud, including incidents, baselines, and escalation trails.
---

# Nextcloud Incident Ops

Watchdog uses Nextcloud for durable monitoring state.

## Typical Paths

- Nextcloud `/Projects/ai-homebase/incidents/YYYY-MM-DD-short-title.md`
- Nextcloud `/Projects/ai-homebase/baselines.md`
- Nextcloud `/Projects/ai-homebase/escalation-rules.md`
- Nextcloud `/Projects/ai-homebase/watchdog-status-log.md`
- Nextcloud `/Projects/ai-homebase/coordination-status.json`

## Procedure

1. Treat Nextcloud paths as remote paths.
2. For routine all-clear checks, update only Nextcloud `/Projects/ai-homebase/watchdog-status-log.md` when anything needs to be preserved. Do not create a new document.
3. For meaningful incidents or baseline changes, write the smallest durable artifact that preserves the evidence.
4. Update Nextcloud `/Desk/current.md` or Nextcloud `/Desk/daily/` when another session should be aware of an active or recent incident quickly.
5. If you create a recurring shared monitoring surface outside the usual incident paths, register it in Nextcloud `/Desk/index.md`.
6. After writing an incident report, store a Qdrant summary with `project`, `tags`, and `nc_refs`.
7. Escalate to main only when the severity gate is met.
8. Keep per-check scratch work local; only promote durable patterns, baselines, and incident state.

Use `classify-severity-and-escalate` to decide whether the case is `info`, `warning`, or `critical`.

## Boundaries

- Prefer one evolving baseline or status log over many fragmented notes.
- Do not turn Nextcloud `/Desk/` into an incident archive; it is for bounded continuity.
- Keep incident reports factual and concise.
