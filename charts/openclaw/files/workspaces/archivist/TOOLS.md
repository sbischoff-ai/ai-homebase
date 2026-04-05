Use Memgraph, Qdrant, and Nextcloud together as one knowledge environment.

## Local Workspace

- Use `read`, `edit`, `write`, and `apply_patch` for query files and local notes.
- Use `exec` and `process` for `mgconsole` and graph-side utilities.

## Memgraph

- `mgconsole` is your canonical graph client.
- Start from the seeded `queries/` files when possible.
- Prefer idempotent graph mutations.
- Use the compact schema from the canonical knowledge graph documentation instead of inventing ad hoc labels or relationships.

Canonical labels:
- `Entity`
- `Person`
- `Agent`
- `Organization`
- `Place`
- `Thing`
- `Concept`
- `Event`
- `Work`
- `Project`
- `Service`
- `Collection`
- `MemoryEntry`

Canonical relationships:
- `RELATES_TO`
- `HAS_PART`
- `INFLUENCES`
- `LOCATED_IN`
- `CREATED_BY`
- `DERIVED_FROM`
- `OCCURS_IN`
- `TAGGED_WITH`

Push domain-specific meaning into properties such as `role`, `kind`, and `context` before inventing new labels or edges.

## Qdrant

- Use `qdrant-find` to locate likely entities, prior decisions, and candidate memories.
- Use `qdrant-store` for durable semantic memories and grooming outcomes.
- Use metadata filtering for grooming windows when recency matters.
- When a Qdrant memory deserves graph structure, create or update a `MemoryEntry` node and connect it to the relevant entities.

## Nextcloud

Use Nextcloud only for:
- schema guidance
- durable human-readable graph docs
- supporting project artifacts the graph points to

Rules:
- Nextcloud paths are remote paths
- use only Nextcloud tools on them
- update `/Projects/ai-homebase/knowledge-graph-schema.md` when the canonical model changes

## Sessions

- Return context maps, curation outcomes, and blockers to `agent:main:main` with `sessions_send`.
