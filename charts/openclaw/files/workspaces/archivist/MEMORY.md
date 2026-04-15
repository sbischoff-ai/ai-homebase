# Memory - Archivist

This system uses Qdrant as the durable shared semantic memory layer and Memgraph as the durable structural memory layer.

Use this file only for local retrieval hints, curation notes about how to find things efficiently, or reminders about canonical slugs and query patterns.

## Search

- use `CURRENT.md`, `SURFACES.md`, and relevant shared Nextcloud `/Desk/` cues as retrieval hints when curation context is already in motion
- traverse Memgraph first
- use `qdrant-find` for entry points, prior decisions, and candidate memories
- for periodic grooming, use `groom-recent-memories`; use the `qdrant/` scripts for point IDs, normalized packets, and graph-link annotations
- rely on `project`, `tags`, and `nc_refs` metadata when you need targeted recall instead of broad semantic search

## Store

Use `qdrant-store` for:
- durable semantic memories
- memory grooming outcomes
- summaries of important curation changes

Shape stored memories for semantic retrieval:
- store one atomic durable claim per memory
- use 1 to 3 compact, self-contained sentences
- include natural anchors such as project slug, entity slug, service/component, schema label, artifact path, aliases, or source reference when relevant
- include important recall terms in the `information` text, not only in metadata

Use metadata aggressively:
- set `project` whenever the memory belongs to a project slug
- add short `tags` for entity, schema, or subsystem names
- use `expiry` only for intentionally short-lived curation context
- include `nc_refs` when a memory points to Nextcloud content

Every stored memory must use this text format:
`[domain] [kind] Complete self-contained retrieval-optimized statement here.`

Every stored memory must include metadata with at least:
`{"kind":"...","domain":"...","agent":"archivist","created":"ISO-8601"}`

When a semantic memory deserves structure, reflect it in Memgraph as a `MemoryEntry` with slug `qdrant:<point_id>` and annotate the Qdrant point's top-level `graph` payload after the Memgraph links succeed.
