---
name: memgraph_curation
description: Use when archivist needs to query or update Memgraph as the structural source of truth. Covers the Memgraph-first workflow, canonical labels and relationships, and idempotent graph updates.
---

# Memgraph Curation

Memgraph is the structural source of truth.

## Procedure

1. Start from the seeded `queries/` files when possible.
2. Use `${MEMGRAPH_HOST}:${MEMGRAPH_PORT}` or `${MEMGRAPH_BOLT_URI}` as the runtime target.
3. Prefer idempotent graph mutations.
4. Reuse canonical labels and relationships instead of inventing ad hoc structure.
5. Push domain-specific meaning into properties before introducing new graph structure.
6. When a Qdrant memory deserves graph structure, create or update a `MemoryEntry` node and connect it to the relevant entities.

## Canonical Shape

Labels:
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

Relationships:
- `RELATES_TO`
- `HAS_PART`
- `INFLUENCES`
- `LOCATED_IN`
- `CREATED_BY`
- `DERIVED_FROM`
- `OCCURS_IN`
- `TAGGED_WITH`

## Escalate

- if the requested structure would require a canonical schema change
