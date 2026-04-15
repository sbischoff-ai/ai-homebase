---
name: check-heartbeat-and-budget
description: Use for heartbeat-driven monitoring, readiness checks, coordination-status checks, or budget sentinel alerts.
---

# Heartbeat And Budget Sentinel

Use for lightweight recurring checks.

## Signals

- gateway readiness endpoint: `http://127.0.0.1:18789/readyz`
- shared coordination status marker: Nextcloud `/Projects/ai-homebase/coordination-status.json`
- spend posture: `tokscale --openclaw --today --json`

## Procedure

1. Read the relevant shared Nextcloud `/Desk/current.md`, Nextcloud `/Desk/index.md`, and local desk cues only when heartbeat or orientation review genuinely needs them.
2. Check readiness.
3. Read the shared coordination status marker when activity context is relevant.
4. Review only the calendars, task lists, or tables registered for `heartbeat` or `orientation` review.
5. Compare against known baselines before calling something a deviation.
6. Compare spend posture against Nextcloud `/Projects/ai-homebase/budget-policy.md` and treat "approaching a ceiling" as a warning signal, not an automatic emergency.
7. Write only compact durable status updates; routine all-clear heartbeat runs should stay in the status log, not expand into new documents.
8. From cron, do not depend on session visibility or session messaging unless the cron prompt explicitly requires it.

## Boundaries

- Respect the rules in `classify-severity-and-escalate`.
- Prefer low false positives over aggressive escalation.
- Do not turn heartbeat review into generic stack housekeeping for higher-cost agents.
