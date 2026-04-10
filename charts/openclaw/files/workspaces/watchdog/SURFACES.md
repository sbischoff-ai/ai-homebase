# Surfaces - Watchdog

Keep only the monitoring surfaces that are active or repeatedly useful.

For each important surface, record:
- type
- stable id or path
- purpose
- steward
- project or domain
- read trigger

## Shared Continuity Surfaces

- Nextcloud `/Desk/current.md` - shared current state - steward: main - trigger: orientation or active-incident
- Nextcloud `/Desk/index.md` - shared surface registry - steward: main - trigger: orientation or heartbeat
- Nextcloud `/Desk/daily/` - shared daily continuity - steward: main - trigger: orientation

## Common Monitoring Surfaces

- Nextcloud `/Projects/ai-homebase/heartbeat.json` - stack liveness handoff - steward: main - trigger: heartbeat
- Nextcloud `/Projects/ai-homebase/watchdog-status-log.md` - durable status summary - steward: watchdog - trigger: orientation
- Nextcloud `/Projects/ai-homebase/baselines.md` - monitoring baselines - steward: watchdog - trigger: orientation
- Nextcloud `/Projects/ai-homebase/escalation-rules.md` - escalation policy - steward: watchdog - trigger: orientation
- Nextcloud `/Projects/ai-homebase/incidents/` - durable incident reports - steward: watchdog - trigger: active-incident
