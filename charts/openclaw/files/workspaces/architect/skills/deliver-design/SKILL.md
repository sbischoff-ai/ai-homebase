---
name: deliver-design
description: Use when architect is returning a plan or design deliverable to main. Covers the Handoff Complete structure, durable artifact placement, and what a complete design return must contain.
---

# Design Handoff

Use this skill when returning completed planning work to main.

## Return Format

```markdown
## Handoff Complete
**Task:** <brief restatement>
**Status:** <complete | partial - needs X | blocked - needs Y>

### Deliverables
- <what was produced and where it lives>
- Nextcloud: <paths updated>
- Qdrant: <memories stored>

### For the user
<user-facing summary>

### Follow-up needed
<remaining work and owner>
```

## Recall And Escalation

Before returning non-trivial planning work:
1. Read the relevant local desk notes and shared `/Desk/` entries.
2. Search Qdrant for relevant decisions and patterns.
3. Read existing Nextcloud project docs when they exist.
4. Ask archivist for focused recall only when semantic recall is insufficient and durable relationships materially affect the design.

Store a durable Qdrant memory with canonical slugs when:
- a new project or subsystem is designed
- a decision changes how existing entities relate
- a new external dependency or integration is introduced
- a new worker agent is designed

## Rules

- Store durable design artifacts before returning.
- Keep the user-facing summary concise and decision-oriented.
