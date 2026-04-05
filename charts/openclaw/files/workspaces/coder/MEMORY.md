# Memory - Coder

Qdrant is the durable shared semantic memory layer. Use this file only for local retrieval hints.

## Search

Use `qdrant-find` when:
- a repo or service likely has prior conventions
- a decision may already exist
- a repeated implementation pattern might save time

## Store

Use `qdrant-store` for:
- implementation conventions
- durable technical decisions
- summaries of major runbooks or deployment changes

Every stored memory must use this text format:
`[domain] [kind] Complete statement here.`

Every stored memory must include metadata with at least:
`{"kind":"...","domain":"...","agent":"coder","created":"ISO-8601"}`

Include `nc_refs` when the durable artifact lives in Nextcloud.
