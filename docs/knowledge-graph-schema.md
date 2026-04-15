# Knowledge Graph Schema

This document defines the canonical Memgraph schema for the user's long-term cross-domain world model. The same starter schema is seeded into Nextcloud for the `archivist`; the live graph may grow from this baseline as real knowledge enters the system.

## Canonical Node Labels

Every node must have the `Entity` label plus one or more specialized labels from this hierarchy:

```text
Entity                    - base label, all nodes have this
|-- Person                - humans, fictional characters, contacts, personas
|-- Agent                 - AI agents (subtype of Person in this system)
|-- Organization          - companies, teams, groups, factions, guilds
|-- Place                 - locations, venues, regions, fictional lands
|-- Thing                 - physical objects, items, equipment, artifacts
|-- Concept               - abstract ideas, topics, skills, fields, genres
|-- Event                 - occurrences with temporal extent (meetings, incidents, sessions, campaigns)
|-- Work                  - creative or intellectual outputs (documents, code, art, publications)
|-- Project               - tracked efforts with goals (software projects, campaigns, trips, research)
|-- Service               - running systems, APIs, platforms, tools
|-- Collection            - named groupings (playlists, reading lists, inventories, tag bundles)
`-- MemoryEntry           - Qdrant-linked memory nodes (grooming artifacts)
```

Use properties instead of inventing more labels unless traversal semantics truly require a new label:

- `domain`: `real` | `fictional` | `speculative` | `synthetic`
- `kind`: freeform subtype
- `category`: freeform grouping
- `status`: `active` | `archived` | `draft` | `completed` | `abandoned`
- `slug`: stable identifier for `MERGE`-based idempotency
- `name`: human-readable display name

## Canonical Relationships

Use this compact set and push domain-specific meaning into relationship properties:

| Relationship | Meaning | Key properties |
| --- | --- | --- |
| `RELATES_TO` | General association; fallback when nothing more specific fits | `role`, `kind`, `context`, `weight` |
| `HAS_PART` | Composition or membership | `role`, `kind`, `since`, `until` |
| `INFLUENCES` | Causal or directional effect | `kind`, `strength`, `context` |
| `LOCATED_IN` | Spatial containment | `kind`, `since`, `until` |
| `CREATED_BY` | Authorship or origin | `role`, `context` |
| `DERIVED_FROM` | Provenance or lineage | `kind`, `context` |
| `OCCURS_IN` | Temporal or narrative containment | `kind`, `sequence` |
| `TAGGED_WITH` | Classification or annotation | `confidence`, `context` |

## Qdrant Linkage

Qdrant remains the semantic memory store. Memgraph stores structural knowledge and graph-promoted memory nodes.

When a Qdrant memory deserves graph structure, `archivist` should:

- retrieve the Qdrant point ID and normalized payload with the seeded `qdrant/` scripts
- create or update a `:Entity:MemoryEntry` node with `slug = "qdrant:<point_id>"`
- store `qdrant_id`, `document_sha256`, `agent`, `domain`, `kind`, `project`, `created`, `summary`, `linked_at`, and optional `memory_ref`
- connect the memory to relevant entities with the standard relationships
- annotate the Qdrant point's top-level `graph` payload only after Memgraph links succeed

Standard memory links:

- memory `CREATED_BY` agent when `metadata.agent` maps to an agent node
- project `HAS_PART {kind: "memory"}` memory when `metadata.project` maps to a project node
- memory `RELATES_TO {kind: "memory-evidence"}` relevant entities selected by archivist
- memory `DERIVED_FROM {kind: "supersedes"}` older `MemoryEntry` when supersession is clear
- memory `TAGGED_WITH` durable tag concepts

The Qdrant graph annotation is bookkeeping, not the source of structural truth. Do not modify Qdrant vectors, `document`, or MCP-managed `metadata` during graph grooming.
