# Surfaces - Watchdog

Read this after `CURRENT.md`.

Keep only the monitoring surfaces that are active or repeatedly useful.

For each important surface, record:
- type
- stable id or path
- purpose
- steward
- project or domain
- read trigger

## Shared Continuity Surfaces

- `/Desk/current.md` - shared current state - steward: main - trigger: startup or active-incident
- `/Desk/index.md` - shared surface registry - steward: main - trigger: startup or heartbeat
- `/Desk/daily/` - shared daily continuity - steward: main - trigger: startup

## Common Monitoring Surfaces

- `/Projects/ai-homebase/heartbeat.json` - stack liveness handoff - steward: main - trigger: heartbeat
- `/Projects/ai-homebase/watchdog-status-log.md` - durable status summary - steward: watchdog - trigger: startup
- `/Projects/ai-homebase/baselines.md` - monitoring baselines - steward: watchdog - trigger: startup
- `/Projects/ai-homebase/escalation-rules.md` - escalation policy - steward: watchdog - trigger: startup
- `/Projects/ai-homebase/incidents/` - durable incident reports - steward: watchdog - trigger: active-incident
