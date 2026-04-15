---
name: update-memgraph
description: Use when querying or updating Memgraph as the structural source of truth, especially for canonical entities, relationships, and memory links.
---

# Memgraph Curation

Memgraph is the structural source of truth.

## Procedure

1. Start from the seeded `queries/` files when possible.
2. Use `python3 queries/run_query.py <query.cypher> --params-json '{...}'` or `--params <file.json>` for parameterized query helpers.
3. Prefer idempotent graph mutations.
4. Reuse canonical labels and relationships instead of inventing ad hoc structure.
5. Push domain-specific meaning into properties before introducing new graph structure.
6. When a Qdrant memory deserves graph structure, use `qdrant/scroll_memories.py` or `qdrant/get_memory.py` to obtain the point ID and normalized packet.
7. Create or update a `MemoryEntry` node with slug `qdrant:<point_id>`, then connect it to the relevant entities with the `queries/` helpers.
8. After Memgraph updates succeed, annotate the Qdrant point with `qdrant/set_graph_link.py`.

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

`MemoryEntry` nodes should carry `slug`, `qdrant_id`, `document_sha256`, `agent`, `domain`, `kind`, `project`, `created`, `summary`, `linked_at`, and optional `memory_ref` when Qdrant metadata already has one.

Relationships:
- `RELATES_TO`
- `HAS_PART`
- `INFLUENCES`
- `LOCATED_IN`
- `CREATED_BY`
- `DERIVED_FROM`
- `OCCURS_IN`
- `TAGGED_WITH`

Standard memory links:
- memory `CREATED_BY` agent
- project `HAS_PART {kind: "memory"}` memory
- memory `RELATES_TO {kind: "memory-evidence"}` selected entities
- replacement memory `DERIVED_FROM {kind: "supersedes"}` older memory
- memory `TAGGED_WITH` durable tag concepts

## Escalate

- if the requested structure would require a canonical schema change
