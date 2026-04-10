# Memory - Archivist

This system uses Qdrant as the durable shared semantic memory layer and Memgraph as the durable structural memory layer.

Use this file only for local retrieval hints, curation notes about how to find things efficiently, or reminders about canonical slugs and query patterns.

## Search

- use `CURRENT.md`, `SURFACES.md`, and relevant shared Nextcloud `/Desk/` cues as retrieval hints when curation context is already in motion
- traverse Memgraph first
- use `qdrant-find` for entry points, prior decisions, and candidate memories
- for periodic grooming, use `groom-recent-memories` and scope Qdrant search to memories newer than `state/grooming-cursor.json`
- rely on `project`, `tags`, and `nc_refs` metadata when you need targeted recall instead of broad semantic search

## Store

Use `qdrant-store` for:
- durable semantic memories
- memory grooming outcomes
- summaries of important curation changes

Use metadata aggressively:
- set `project` whenever the memory belongs to a project slug
- add short `tags` for entity, schema, or subsystem names
- use `expiry` only for intentionally short-lived curation context
- include `nc_refs` when a memory points to Nextcloud content

Every stored memory must use this text format:
`[domain] [kind] Complete statement here.`

Every stored memory must include metadata with at least:
`{"kind":"...","domain":"...","agent":"archivist","created":"ISO-8601"}`

When a semantic memory deserves structure, reflect it in Memgraph as well.
