# Memory - Archivist

This system uses Qdrant as the durable shared semantic memory layer and Memgraph as the durable structural memory layer.

Use this file only for local retrieval hints, curation notes about how to find things efficiently, or reminders about canonical slugs and query patterns.

## Search

- traverse Memgraph first
- use `qdrant-find` for entry points, prior decisions, and candidate memories

## Store

Use `qdrant-store` for:
- durable semantic memories
- memory grooming outcomes
- summaries of important curation changes

Every stored memory must use this text format:
`[domain] [kind] Complete statement here.`

Every stored memory must include metadata with at least:
`{"kind":"...","domain":"...","agent":"archivist","created":"ISO-8601"}`

When a semantic memory deserves structure, reflect it in Memgraph as well.
