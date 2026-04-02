# Knowledge Graph Schema

This document defines the initial canonical Memgraph schema for long-term OpenClaw knowledge.

Stable label vocabulary:
- `Entity`
- `Person`
- `User`
- `Agent`
- `Service`
- `System`
- `Project`
- `Repository`
- `MemoryEntry`

Stable relationship vocabulary:
- `HAS_MEMBER`
- `USES`
- `PART_OF`
- `MANAGES`
- `REFERS_TO`
- `RELATES_TO`
- `DERIVED_FROM`

Rules:
- prefer existing labels and relationships over inventing new ones;
- use multiple labels when an entity belongs to several stable types;
- attach type-specific metadata but keep canonical fields stable;
- add `Entity` to durable nodes unless there is a strong reason not to;
- use relationship properties such as `role`, `kind`, or `context` before inventing a new relationship type;
- represent Qdrant memories as `MemoryEntry` nodes with their Qdrant ID in metadata;
- connect memory nodes to entities so graph traversal and semantic search can be composed.
