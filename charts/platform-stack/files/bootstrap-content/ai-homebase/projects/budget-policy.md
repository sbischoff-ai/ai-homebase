# LLM Budget Policy

This file is the shared budget policy for the `ai-homebase` stack.

Purpose:
- make the stack's LLM budget rules visible to the user;
- define the current spending posture for the standing agents and Codex-assisted work;
- give the user one durable place to review and change budget policy.

Working rule:
- `main` is the budget manager for routine delegation decisions;
- agents should treat this file as the canonical source for budget thresholds and escalation posture;
- if the user wants to change budget behavior, update this file instead of hiding those rules in seeded workspace prompts.

## Cost Surfaces

The stack tracks LLM usage on two main surfaces:
- gateway-side OpenClaw session spend via `tokscale`;
- Codex usage logged by `coder` in `/Projects/ai-homebase/codex-usage/YYYY-MM-DD.json`.

Important note:
- `tokscale` groups spend by model, not by agent, so per-agent posture is approximate and should be interpreted using the standing model assignments.

## Hard Ceilings

- daily: `$15`
- weekly: `$50`
- monthly: `$150`

These are the primary user-managed guardrails for the standard stack posture.

## Soft Reference Thresholds

These are planning references, not hard stops:
- `main`: `$1` per day
- `architect`: `$5` per day
- `coder` agent session: `$5` per day
- Codex CLI usage: `$4` per day
- `archivist`: `$1` per day
- `watchdog`: `$0.50` per day
- `auditor`: `$2` per day

## Delegation Classes

- `P0`: direct user requests always proceed
- `P1`: active handoffs proceed unless a hard ceiling is at risk
- `P2`: proactive work defers once the daily ceiling is reached or weekly spend exceeds `$40`
- `P3`: speculative work skips when monthly spend exceeds `$120` or weekly spend exceeds `$40`

## Monitoring And Review Posture

- `watchdog` should alert `main` when total daily spend exceeds `$12`, because the stack is approaching the daily hard ceiling
- heartbeat-driven polling should default to `watchdog` or a Nano worker; adding heartbeat to a higher-cost agent is an explicit exception that should be user-aware
- recurring non-reactive work for higher-cost agents should prefer sparse cron such as nightly or weekly instead of a 30-minute loop
- `auditor` should stay conservative and prefer compact review packets
- reference review posture:
  - on-demand reviews should usually stay under `30K` input tokens
  - weekly audit passes should usually stay under `50K` input tokens total

These review numbers are cost-discipline guidance, not hard functional limits.

## Off-Budget Sessions

If the user explicitly says work is off-budget:
- note that status in the handoff;
- specialists may skip their normal self-checks;
- the user is intentionally overriding the default spending posture for that work.

## User Control

This file is intentionally part of `/Projects/ai-homebase/`, which is shared with the user during bootstrap.

If the user wants a different budget posture, update this document and treat the new values as the current policy.

## Maintenance Rule

`main` must keep this file current when the live agent roster changes.

Update this document when:
- a new worker or other agent is added and it introduces meaningful ongoing LLM spend
- an agent is retired and the expected spend posture changes
- an existing agent is materially re-scoped and its expected budget guidance changes

This document should reflect the current live topology, not only the original bootstrap defaults.
