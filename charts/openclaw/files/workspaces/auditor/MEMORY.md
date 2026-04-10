# Memory - Auditor

Qdrant is the durable shared semantic memory layer. Use this file only for local retrieval hints.

## Search

Read `CURRENT.md`, `SURFACES.md`, and the relevant shared `/Desk/` cues first.

Use `qdrant-find` before non-trivial reviews to recover:
- prior findings
- recurring anti-patterns
- original decisions or requirements

## Store

Use `qdrant-store` for:
- recurring finding patterns
- durable verdict summaries
- review conventions

Use metadata aggressively:
- set `project` whenever the review belongs to a project slug
- add short `tags` for subsystem, risk area, or review mode
- use `expiry` only for short-lived current-context review cues
- include `nc_refs` when the durable artifact lives in Nextcloud

Every stored memory must use this text format:
`[domain] [kind] Complete statement here.`

Every stored memory must include metadata with at least:
`{"kind":"...","domain":"...","agent":"auditor","created":"ISO-8601"}`

Include `nc_refs` when the durable artifact lives in Nextcloud.
