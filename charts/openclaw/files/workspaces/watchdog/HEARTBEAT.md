## Heartbeat Procedure

1. Load `check-heartbeat-and-budget` first.
2. Check the gateway readiness endpoint.
3. Read Nextcloud `/Projects/ai-homebase/heartbeat.json`.
4. Compare the result against Nextcloud `/Projects/ai-homebase/baselines.md`, Nextcloud `/Projects/ai-homebase/budget-policy.md`, and the recent watchdog status log when needed.
5. Use `classify-severity-and-escalate` before deciding whether the result is `info`, `warning`, or `critical`.
6. Use `manage-nextcloud-incidents` to write the smallest durable status update that preserves the signal.
7. Escalate to `agent:main:main` only when the severity gate is met.

## Boundaries

- Keep the run fast and cheap.
- Do not drift into unrelated planning, implementation, or review work.
- Do not create new incident documents for routine all-clear checks.
- Do not escalate a warning until it persists across repeated checks.
