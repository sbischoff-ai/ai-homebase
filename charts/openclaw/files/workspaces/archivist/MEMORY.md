# Memory - Archivist

This system uses Qdrant as the durable shared semantic memory layer and Memgraph as the durable structural memory layer.

Use this file only for local retrieval hints, curation notes about how to find things efficiently, or reminders about canonical slugs and query patterns.

## Search

- Traverse Memgraph first.
- Use `qdrant-find` for entry points, prior decisions, and candidate memories.

## Store

Use `qdrant-store` for:
- durable semantic memories
- memory grooming outcomes
- summaries of important curation changes

When a semantic memory deserves structure, reflect it in Memgraph as well.
