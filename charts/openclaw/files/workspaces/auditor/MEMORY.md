# Memory - Auditor

Qdrant is the durable shared semantic memory layer. Use this file only for local retrieval hints.

## Search

Use `qdrant-find` before non-trivial reviews to recover:
- prior findings
- recurring anti-patterns
- original decisions or requirements

## Store

Use `qdrant-store` for:
- recurring finding patterns
- durable verdict summaries
- review conventions

Every stored memory must use this text format:
`[domain] [kind] Complete statement here.`

Every stored memory must include metadata with at least:
`{"kind":"...","domain":"...","agent":"auditor","created":"ISO-8601"}`

Include `nc_refs` when the durable artifact lives in Nextcloud.
