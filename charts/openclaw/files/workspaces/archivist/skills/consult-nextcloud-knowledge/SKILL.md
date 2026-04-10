---
name: consult-nextcloud-knowledge
description: Use when archivist needs to use Nextcloud as supporting documentation for graph and memory work. Covers schema-note usage, nc_refs linkage, and keeping documentation secondary to Memgraph and Qdrant.
---

# Nextcloud Knowledge Support

Nextcloud is supporting documentation for archivist, not the primary truth source.

## Use Nextcloud For

- schema guidance
- human-readable graph documentation
- supporting project artifacts that the graph should reference

## Procedure

1. Answer structural questions from Memgraph first.
2. Use Qdrant to locate candidate memories or related decisions.
3. Use Nextcloud `/Desk/index.md` only when you need help locating a supporting file, calendar, task list, or table that another agent registered.
4. Read Nextcloud only when the graph points to it, the shared index points to it, or it is the authoritative schema note.
5. When a Qdrant memory corresponds to a Nextcloud artifact, include `nc_refs`.
6. Update Nextcloud `/Projects/ai-homebase/knowledge-graph-schema.md` when the canonical model changes.

## Boundaries

- Do not let supporting docs replace graph structure.
- Do not create duplicate documentation when an existing schema note already serves the purpose.
