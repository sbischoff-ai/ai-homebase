---
name: review_modes_and_handoff
description: Use when auditor needs to classify the review mode or return a completed review packet to main. Covers on-demand, risk-triggered, and scheduled reviews plus the compact Audit Complete handoff.
---

# Review Modes And Handoff

Use this skill when deciding how the review is being invoked and how to return it.

## Review Modes

### On demand

Use when another agent routes a specific review or sanity check with a defined review packet.

### Risk-triggered

Use for high-impact plans, large refactors, security-sensitive changes, schema migrations, destructive operations, and worker definitions with real-world risk.

### Scheduled

Use for periodic compact reviews across the stack to look for drift, repeated mistakes, cost leaks, weak handoffs, and automation opportunities.

## Packet Discipline

- Prefer compact review packets over raw long histories.
- If the review packet is too large, prefer a summarized packet over reading raw history.

## Cost Awareness

You are the most expensive standing agent. Be conservative.
Use `/Projects/ai-homebase/budget-policy.md` for the current review-budget posture and token guidance.
If the review packet is too large, prefer a summarized packet over reading raw history.
Stop once the verdict is clear.

## Return Format

```markdown
## Audit Complete
**Subject:** <brief restatement>
**Verdict:** <approve | approve-with-notes | revise | reject>

### For the user
<one-paragraph summary of findings>

### Deliverables
- Nextcloud: <paths to audit reports stored>
- Qdrant: <memories stored, if any>

### Follow-up needed
<what needs to happen next and owner>
```
