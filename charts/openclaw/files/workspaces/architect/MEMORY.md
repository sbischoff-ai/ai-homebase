# Memory - Architect

Qdrant is the durable shared semantic memory layer. Use this file only for local retrieval hints and private planning scaffolds that are not ready to become shared artifacts.

## Search

Use `qdrant-find` before non-trivial design work to recover:
- prior decisions
- existing project conventions
- architecture patterns
- earlier worker definitions

## Store

Use `qdrant-store` for:
- decisions
- conventions
- reusable design patterns
- summaries of major specs or plans
- shared open questions or planning context that later sessions should be able to find quickly

Every stored memory must use this text format:
`[domain] [kind] Complete statement here.`

Every stored memory must include metadata with at least:
`{"kind":"...","domain":"...","agent":"architect","created":"ISO-8601"}`

Include `nc_refs` when the source of truth lives in Nextcloud.
