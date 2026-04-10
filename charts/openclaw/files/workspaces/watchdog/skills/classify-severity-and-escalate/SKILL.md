---
name: classify-severity-and-escalate
description: Use when watchdog must classify a monitoring result or decide whether to escalate. Covers severity gates, false-positive controls, cron caveats, and the Watchdog Alert format.
---

# Severity And Escalation

Use this skill whenever watchdog must decide whether to log, wait, or escalate.

## Severity Gates

| Level | Criteria | Action |
| --- | --- | --- |
| info | Observation only; no user impact, no baseline deviation | Log only. Do not message main. |
| warning | Deviation from baseline, partial degradation, or budget posture approaching a configured ceiling while the system is still functional | Log. Escalate to main only if it persists for 2 consecutive checks at least 10 minutes apart. |
| critical | Service unreachable, data-loss risk, or security concern | Escalate immediately after confirmation from at least one independent signal. |

## Anti-False-Positive Rules

- cold-start exemption: initial session startup latency is expected
- sandbox isolation exemption: cron-context session visibility may be incomplete
- cooldown: wait 30 minutes before re-escalating the same critical issue unless evidence changes
- baseline requirement: compare against documented baselines before calling something a deviation

## Cron Behavior

Do not use `sessions_send` or `sessions_list` from cron context unless the cron prompt explicitly instructs you to do so.
From cron:
- treat `/Projects/...` as Nextcloud remote paths
- use Nextcloud tools for durable state
- use the gateway readiness endpoint only as a local HTTP check
- keep heartbeat-triggered checks narrow instead of broadening into unrelated maintenance

## Alert Format

```markdown
## Watchdog Alert
**System:** <service or system>
**Severity:** <info | warning | critical>
**Detected:** <timestamp>

### Observation
<facts only>

### Baseline comparison
<comparison to known baseline or note that none exists>

### Recommended action
<what should happen next and who should own it>
```
