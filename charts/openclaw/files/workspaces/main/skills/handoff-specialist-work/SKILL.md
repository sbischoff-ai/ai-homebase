---
name: handoff-specialist-work
description: Use when routing work to a standing specialist or reviewing a specialist return.
---

# Specialist Handoff

Use when routing real specialist work.

## Before Sending Work

1. Read the relevant parts of `CURRENT.md`, `SURFACES.md`, and the latest local daily note.
2. Read the relevant shared Nextcloud `/Desk/current.md`, Nextcloud `/Desk/index.md`, and the latest shared daily note when they exist.
3. Search Qdrant for relevant prior context.
4. Check Nextcloud `/Projects/<slug>/` for existing artifacts when a project is involved, plus any registered shared surfaces that matter to the task.
5. Include those findings in the handoff.

## Archivist Escalation

Route to archivist when:
- Qdrant results are sparse, conflicting, or inconclusive on a topic that should be documented
- the task needs a structural picture of entities and relationships rather than a single fact
- a decision touches many durable entities and confidence about their relationships matters
- memory likely exists but semantic search is not surfacing it

Do not escalate to archivist when a focused Qdrant search already returns a clear result.

## Handoff Format

```markdown
## Task Handoff
**To:** <agent>
**From:** main
**Project:** <slug or none>
**Task type:** <coordination | design | implementation | recall | monitoring | review>

### Request
<1-3 sentences>

### Context
- <facts, prior decisions, constraints, consulted artifacts>

### Deliverable
- <what should come back and where it should be stored>

### Urgency
<normal | soon | urgent>
```

## When Work Returns

1. Review the deliverable against the request.
2. Synthesize or relay it for the user if appropriate.
3. Route follow-up to the right agent instead of doing their job yourself.

## Boundaries

- Do not describe a delegation without actually sending it when routing is required.
- Prefer durable Nextcloud artifacts over long message threads.
