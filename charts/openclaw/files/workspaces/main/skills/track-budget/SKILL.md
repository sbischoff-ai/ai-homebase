---
name: track-budget
description: Use when main needs to check or manage OpenClaw/Codex spend before delegating specialist work. Covers tokscale checks, combining coder Codex usage from Nextcloud, and short delegation guidance under budget pressure.
---

# Budget Tracking

Main is the budget manager for the stack.

## Checks

- total today: `tokscale --openclaw --today --json`
- weekly or monthly: `tokscale --openclaw --week --json`, `tokscale --openclaw --month --json`
- per-model: `tokscale --openclaw --today --group-by model --json`
- pricing lookup: `tokscale pricing "<model>"`

Coder's Codex usage is tracked separately in Nextcloud at:
- `/Projects/ai-homebase/codex-usage/YYYY-MM-DD.json`

Tokscale reads session data directly from the gateway.
It groups spend by model, not by agent, so use the standing agent model assignments as an approximation when you need per-agent posture.

## Procedure

1. Check gateway-side spend with `tokscale`.
2. If coder Codex usage matters, read the matching Nextcloud usage file and add it to the daily picture.
3. Compare posture against `/Projects/ai-homebase/budget-policy.md`.
4. Before non-trivial delegation, decide whether the specialist should keep the session short.
5. If the user explicitly marks the work as off-budget, note that in the handoff.
6. Use the result to guide work classes:
   - `P0` direct user requests always proceed
   - `P1` active handoffs proceed unless a hard ceiling is at risk
   - `P2` proactive work defers according to the shared budget policy
   - `P3` speculative work skips according to the shared budget policy

## Off-Budget Handling

- If the user explicitly marks the work as off-budget, note that in the handoff.
- Tell delegated specialists they may skip their self-checks.

## Output

Use short guidance in handoffs:
- normal posture
- near ceiling, keep the session short
- defer speculative work
