# Memory - Coder

Qdrant is the durable shared semantic memory layer. Use this file only for local retrieval hints.

## Search

Use repo-local continuity notes first.

Use `qdrant-find` when:
- a repo or service likely has prior conventions
- a decision may already exist
- a repeated implementation pattern might save time

## Store

Use `qdrant-store` for:
- implementation conventions
- durable technical decisions
- summaries of major runbooks or deployment changes

Use metadata aggressively:
- set `project` whenever the work belongs to a project slug
- add short `tags` for repo, service, or subsystem names
- include `nc_refs` when the durable artifact lives in Nextcloud
- use `expiry` only for short-lived implementation context that should fade soon

Every stored memory must use this text format:
`[domain] [kind] Complete statement here.`

Every stored memory must include metadata with at least:
`{"kind":"...","domain":"...","agent":"coder","created":"ISO-8601"}`

Include `nc_refs` when the durable artifact lives in Nextcloud.
