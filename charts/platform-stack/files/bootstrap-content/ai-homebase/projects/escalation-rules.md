# Escalation Rules

| Severity | Gate | Follow-up owner |
| --- | --- | --- |
| info | Expected behavior, first observation, or no user-visible impact | watchdog documents it and updates baselines if needed |
| warning | Repeated deviation, degraded behavior, or issue needing scheduled follow-up | watchdog notifies main; main decides routing |
| critical | User-visible outage, data-risk condition, or sustained control-plane failure | watchdog escalates to main immediately; main coordinates response |

## Anti-False-Positive Rules
- Cold-start exemption: do not escalate slow first response from a newly created session if it falls within the documented cold-start baseline.
- Sandbox isolation exemption: do not escalate `sessions_list` returning 0 from sandboxed cron context; that is expected isolation behavior.
- 30-minute cooldown: do not re-raise the same warning or critical condition more than once within 30 minutes unless severity increases.
- Baseline requirement: before classifying anything as a deviation, compare it against `/Projects/ai-homebase/baselines.md`. If no baseline exists, log it as info and propose a baseline instead of escalating.

Ownership note:
- `info` stays with `watchdog`.
- `warning` goes from `watchdog` to `main` for prioritization and delegation.
- `critical` goes directly to `main`, which owns immediate coordination and follow-up assignment.
