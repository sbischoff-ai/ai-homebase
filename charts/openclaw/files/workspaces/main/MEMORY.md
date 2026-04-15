# Memory - Main

This deployment uses Qdrant as the durable shared semantic memory layer. Archivist plus Memgraph handles long-horizon curation and graph structure.

Use this file only for local retrieval hints and recurring lookup notes. Do not treat it as the primary long-term memory store; private rough work stays here or in other workspace files until it should become shared recall.

## Search

Use `CURRENT.md`, `SURFACES.md`, and the shared Nextcloud `/Desk/` cues as retrieval hints when the task has ongoing context.

Use `qdrant-find` before non-trivial coordination when:
- the user has ongoing project history
- a prior decision might exist
- a specialist handoff would benefit from recalled context
- a user preference may already be known
- recent work may matter but the user has not restated it yet

## Store

Use `qdrant-store` for:
- durable user preferences
- project-level decisions
- stack rules and operating conventions
- durable artifact summaries
- shared quick note-like context that should influence later work but does not need a user-facing document yet

Shape stored memories for semantic retrieval:
- store one atomic durable claim per memory
- use 1 to 3 compact, self-contained sentences
- include natural anchors such as project slug, service/component, agent/person, artifact path, aliases, incident name, or source reference when relevant
- include important recall terms in the `information` text, not only in metadata

Use metadata aggressively:
- set `project` whenever the memory belongs to a project slug
- add 1 to 4 short `tags` for discoverability
- use `expiry` for short-lived current-context memories that should fade after the near term
- include `nc_refs` whenever the memory points to a Nextcloud artifact or shared surface

Every stored memory must use this text format:
`[domain] [kind] Complete self-contained retrieval-optimized statement here.`

Every stored memory must include metadata with at least:
`{"kind":"...","domain":"...","agent":"main","created":"ISO-8601"}`

When a memory corresponds to Nextcloud content, include `nc_refs`.

## Carry-Forward Review

Before returning a non-trivial result or deferring unfinished work:
- update the local desk if a future run will need a quick briefing
- update shared Nextcloud `/Desk/` continuity when another agent or the user will need the current state
- verify you stored memories for durable artifacts, decisions, and reusable coordination context
