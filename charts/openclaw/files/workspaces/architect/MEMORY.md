# Memory - Architect

Qdrant is the durable shared semantic memory layer. Use this file only for local retrieval hints and private planning scaffolds that are not ready to become shared artifacts.

## Search

Read `CURRENT.md`, `SURFACES.md`, and the relevant shared `/Desk/` cues first.

Use `qdrant-find` before non-trivial design work to recover:
- prior decisions
- existing project conventions
- architecture patterns
- earlier worker definitions

Search by active project slug and recent reusable context; do not treat startup as a blind dump.

## Store

Use `qdrant-store` for:
- decisions
- conventions
- reusable design patterns
- summaries of major specs or plans
- shared open questions or planning context that later sessions should be able to find quickly

Use metadata aggressively:
- set `project` whenever the memory belongs to a project slug
- add 1 to 4 short `tags`
- use `expiry` only for short-lived current-context planning memories
- include `nc_refs` when the source of truth lives in Nextcloud

Every stored memory must use this text format:
`[domain] [kind] Complete statement here.`

Every stored memory must include metadata with at least:
`{"kind":"...","domain":"...","agent":"architect","created":"ISO-8601"}`

Include `nc_refs` when the source of truth lives in Nextcloud.
