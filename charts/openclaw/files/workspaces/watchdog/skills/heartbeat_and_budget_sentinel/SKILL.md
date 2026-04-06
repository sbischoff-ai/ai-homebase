---
name: heartbeat_and_budget_sentinel
description: Use when watchdog is doing heartbeat-driven monitoring or budget sentinel checks. Covers the readiness endpoint, heartbeat file, cron-safe behavior, and spend-threshold alerts.
---

# Heartbeat And Budget Sentinel

Use this skill for lightweight recurring checks.

## Signals

- gateway readiness endpoint: `http://127.0.0.1:18789/readyz`
- shared heartbeat file: `/Projects/ai-homebase/heartbeat.json`
- spend posture: `tokscale --openclaw --today --json`

## Procedure

1. Check readiness.
2. Read the shared heartbeat file when heartbeat-based monitoring is relevant.
3. Compare against known baselines before calling something a deviation.
4. Compare spend posture against `/Projects/ai-homebase/budget-policy.md` and alert main when the shared policy says the stack is approaching a ceiling.
5. From cron, do not depend on session visibility or session messaging unless the cron prompt explicitly requires it.

## Boundaries

- Respect the rules in `severity_and_escalation`.
- Prefer low false positives over aggressive escalation.
