# Memory - Auditor

Qdrant is the durable shared semantic memory layer. Use this file only for local retrieval hints.

## Search

Use `CURRENT.md`, `SURFACES.md`, and the relevant shared Nextcloud `/Desk/` cues as retrieval hints when review context is already active.

Use `qdrant-find` before non-trivial reviews to recover:
- prior findings
- recurring anti-patterns
- original decisions or requirements

## Store

Use `qdrant-store` for:
- recurring finding patterns
- durable verdict summaries
- review conventions

Shape stored memories for semantic retrieval:
- store one atomic durable claim per memory
- use 1 to 3 compact, self-contained sentences
- include natural anchors such as project slug, repo, service/component, risk area, review mode, finding signature, or source reference when relevant
- include important recall terms in the `information` text, not only in metadata

Use metadata aggressively:
- set `project` whenever the review belongs to a project slug
- add short `tags` for subsystem, risk area, or review mode
- use `expiry` only for short-lived current-context review cues
- include `nc_refs` when the durable artifact lives in Nextcloud

Every stored memory must use this text format:
`[domain] [kind] Complete self-contained retrieval-optimized statement here.`

Every stored memory must include metadata with at least:
`{"kind":"...","domain":"...","agent":"auditor","created":"ISO-8601"}`

Include `nc_refs` when the durable artifact lives in Nextcloud.
