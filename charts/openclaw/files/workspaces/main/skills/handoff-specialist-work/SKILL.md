---
name: handoff-specialist-work
description: Use when routing work to a standing specialist or reviewing a specialist return.
---

# Specialist Handoff

Use when routing real specialist work.

## Before Sending Work

1. Read the relevant parts of `CURRENT.md`, `SURFACES.md`, and the latest local daily note.
2. Read the relevant shared Nextcloud `/Desk/current.md`, Nextcloud `/Desk/index.md`, and the latest shared daily note when they exist.
3. Search Qdrant only when you need context to decide which specialist should own the work, what artifact governs it, or whether prior decisions materially constrain the request. Do not pre-scan a specialist's own domain sources on their behalf.
4. Check Nextcloud `/Projects/<slug>/` only to confirm whether a governing artifact or already-shared project context exists. Do not pre-digest the artifact into your handoff.
5. If the task needs both design and implementation, choose the execution mode before sending any specialist work.
6. Include routing context, references, and explicit constraints in the handoff. Do not include pre-digested specialist-domain findings.

## Archivist Escalation

Route to archivist when:
- Qdrant results are sparse, conflicting, or inconclusive on a topic that should be documented
- the task needs a structural picture of entities and relationships rather than a single fact
- a decision touches many durable entities and confidence about their relationships matters
- memory likely exists but semantic search is not surfacing it

Do not escalate to archivist when a focused Qdrant search already returns a clear result.

## Archivist Boundaries

When routing graph or curation work to archivist:
- Specify scope, urgency, the triggering question, and relevant artifacts.
- Do not prescribe which entities to create, which relations to form, or which Qdrant memories to promote.
- Do not request targeted graph grooming, targeted promotion, or partial checkpointed graph maintenance.
- When durable graph updates are needed, ask archivist to run the canonical general grooming procedure across all Qdrant additions and Nextcloud changes since the last checkpoint.
- Say "run your normal general grooming procedure" rather than "create entity X with relation Y."
- The only exception is when the user explicitly requests a specific graph mutation.

Targeted archivist requests are for retrieval, context maps, Cypher lookup, and structural recall, not for partial graph maintenance.

Graph-shape decisions belong to archivist. Main owns what to groom and why; archivist owns how the graph changes.

## Handoff Format

```markdown
## Task Handoff
**To:** <agent>
**From:** main
**Project:** <slug or none>
**Task type:** <coordination | design | implementation | recall | monitoring | review>
**Execution mode:** <spec-first | direct-build | post-implementation-follow-up>
**Governing artifact:** <path | none>

### Request
<1-3 sentences>

### Context
- Governing artifact: <path or none>
- Related prior decisions: <Qdrant search cues or none known>
- User constraints: <explicit user instructions or none>
- Do not duplicate the governing artifact's content here.

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
- Do not assume the specialist already knows your local desk state, shared `/Desk/` state, or retrieved project artifacts unless you put them in the handoff.
- Do not turn context gathering into specialist-domain pre-work.
- Do not request an architect spec and coder implementation in parallel for the same change.
