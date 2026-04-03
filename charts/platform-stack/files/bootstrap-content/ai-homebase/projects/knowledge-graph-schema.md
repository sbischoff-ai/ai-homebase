# Knowledge Graph Schema

This document defines the canonical Memgraph schema for the user's long-term cross-domain world model.

## Canonical node labels

Every node must have the `Entity` label plus one or more specialized labels from this hierarchy:

```text
Entity                    — base label, all nodes have this
├── Person                — humans, fictional characters, contacts, personas
├── Agent                 — AI agents (subtype of Person in this system)
├── Organization          — companies, teams, groups, factions, guilds
├── Place                 — locations, venues, regions, fictional lands
├── Thing                 — physical objects, items, equipment, artifacts
├── Concept               — abstract ideas, topics, skills, fields, genres
├── Event                 — occurrences with temporal extent (meetings, incidents, sessions, campaigns)
├── Work                  — creative or intellectual outputs (documents, code, art, publications)
├── Project               — tracked efforts with goals (software projects, campaigns, trips, research)
├── Service               — running systems, APIs, platforms, tools
├── Collection            — named groupings (playlists, reading lists, inventories, tag bundles)
└── MemoryEntry           — Qdrant-linked memory nodes (grooming artifacts)
```

### Properties for specialization

Use properties instead of inventing more labels unless traversal semantics truly require a new one:

- `domain`: `real` | `fictional` | `speculative` | `synthetic`
- `kind`: freeform string for subtype (for example `repository`, `NPC`, `recipe`, `medication`)
- `category`: freeform grouping (for example `source-control`, `fantasy`)
- `status`: `active` | `archived` | `draft` | `completed` | `abandoned`
- `slug`: stable identifier for `MERGE`-based idempotency
- `name`: human-readable display name

### When to add a new label

Only add a new label if the concept requires structurally different traversal patterns or if it would be queried independently by label very frequently. If the concept can be represented with `kind` on an existing label, do not add a label.

## Canonical relationships

Use this compact set of reusable relationships and push domain-specific semantics into relationship properties:

| Relationship | Meaning | Key properties |
| --- | --- | --- |
| `RELATES_TO` | General association; fallback when nothing more specific fits | `role`, `kind`, `context`, `weight` |
| `HAS_PART` | Composition or membership: project has member, organization has department, collection has item, system has component | `role`, `kind`, `since`, `until` |
| `INFLUENCES` | Causal or directional effect: person influences decision, event influences project, concept influences work, medication influences condition | `kind`, `strength`, `context` |
| `LOCATED_IN` | Spatial containment: person lives in place, event happens at place, service runs on infrastructure, item stored in location | `kind`, `since`, `until` |
| `CREATED_BY` | Authorship or origin: work created by person, project started by organization, memory stored by agent, artifact made by character | `role`, `context` |
| `DERIVED_FROM` | Provenance or lineage: work based on work, decision derived from plan, fork from repo, adaptation from source material | `kind`, `context` |
| `OCCURS_IN` | Temporal or narrative containment: event occurs in project, scene occurs in campaign, transaction occurs in period, session occurs in day | `kind`, `sequence` |
| `TAGGED_WITH` | Classification or annotation: any entity tagged with a concept, topic, or category | `confidence`, `context` |

### Relationship properties

Every relationship may use these properties for specialization:

- `role`: the specific role of this connection (for example `maintainer`, `antagonist`, `primary-care`)
- `kind`: sub-type of the relationship (for example on `HAS_PART`: `member`, `component`, `chapter`)
- `context`: freeform note about why this relationship exists
- `since` / `until`: ISO-8601 timestamps for temporal relationships
- `weight` / `strength`: numeric relevance from `0.0` to `1.0` for weighted traversals
- `confidence`: for inferred relationships (`high`, `medium`, `low`)

### When to add a new relationship

Only add a new relationship if it has genuinely different traversal semantics that cannot be expressed with `kind` or `role` on an existing one. If an existing relationship plus properties can express the fact, do not add a new relationship.

Examples:

- "Person X plays in Campaign Y" becomes `Campaign -[:HAS_PART {role: "player"}]-> Person`
- "Doctor prescribed medication" becomes `Person -[:INFLUENCES {kind: "prescription"}]-> Thing`
