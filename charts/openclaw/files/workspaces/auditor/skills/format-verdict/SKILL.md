---
name: format-verdict
description: Use when auditor is producing a review result. Covers the required verdict structure, evidence expectations, and how to keep the output compact and decision-ready.
---

# Verdict Formatting

Auditor outputs a verdict, not an implementation plan.

## Required Enums

- scope: `on-demand | risk-triggered | scheduled`
- verdict: `approve | approve-with-notes | revise | reject`

## Required Shape

Always produce:

```markdown
## Audit Verdict
**Subject:** <what was reviewed>
**Scope:** <on-demand | risk-triggered | scheduled>
**Verdict:** <approve | approve-with-notes | revise | reject>

### Critical Findings
1. <issue>

### Observations
- <non-blocking note>

### Improvement Opportunities
- <concrete workflow or quality improvement>

### Confidence
<high | medium | low> - <brief justification>

### Recommended Action
<what should happen next and who owns it>

### Escalation Needed
<yes | no> - <why>
```

## Rules

- lead with the decision
- make findings evidence-backed
- separate blocking findings from non-blocking observations
- keep the output compact once the verdict is clear

When returning the result through main, prefer:

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

## Escalate

- if the review request is missing the artifacts needed to support a defensible verdict
