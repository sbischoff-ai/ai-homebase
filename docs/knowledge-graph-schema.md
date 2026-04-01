# Knowledge Graph Schema

This document defines the repo-managed baseline schema for the Memgraph knowledge graph curated by the `archivist` agent.

## Summary

The graph complements Qdrant rather than replacing it:

- Qdrant remains the shared semantic-memory store for all agents.
- Memgraph stores durable entities, relationships, and graph-linked memory nodes.
- `archivist` is the schema gatekeeper and the primary graph curator.

## Stable labels

- `Entity`
- `Person`
- `User`
- `Agent`
- `Service`
- `System`
- `Project`
- `Repository`
- `MemoryEntry`

Use multiple labels when they fit one canonical entity, for example `:Entity:Agent:Person` or `:Entity:Project:System`.
For durable first-class nodes, prefer including `Entity` unless there is a clear reason not to.

## Stable relationships

- `HAS_MEMBER`
- `USES`
- `PART_OF`
- `MANAGES`
- `REFERS_TO`
- `RELATES_TO`
- `DERIVED_FROM`

Prefer an existing relationship over inventing a new one unless there is a clear modeling gap.
When semantics differ only by responsibility or context, keep the relationship type broad and store the distinction on the edge with properties such as `role`, `kind`, or `context`.

## Metadata guidance

Keep canonical fields stable and type-oriented:

- entities should carry stable identifiers such as `slug`, `name`, `domain`, `kind`, `category`, or `role`
- memory nodes should carry the Qdrant ID plus provenance fields such as `agent`, `domain`, `kind`, and timestamps
- relationship properties are preferred over relationship-type sprawl when modeling role-specific semantics
- label-specific metadata is acceptable, but avoid ad hoc field drift

## Qdrant linkage

When a Qdrant memory deserves graph structure:

- create or update a `MemoryEntry` node
- store the Qdrant ID in node metadata
- connect that node to the relevant entities
- keep the semantic memory in Qdrant and the structural context in Memgraph

This enables graph traversal first and semantic search second, or the reverse, depending on the task.

## Initial seeded graph

Fresh cluster bootstrap seeds at least:

- the user
- `ai-homebase`
- OpenClaw
- `main`, `architect`, `coder`, `archivist`, and `watchdog`
- Nextcloud, Qdrant, Memgraph, Memgraph Lab, Gitea, Argo CD, and the registry
- the GitOps repo and sandbox-images repo

The seed is idempotent and intended as a stable baseline, not as a complete world model.
The seeded edges deliberately stay broad:

- `HAS_MEMBER` for membership, such as project to user
- `USES` for dependencies and tooling/resource use, including services and repositories
- `PART_OF` for containment, such as specialist agents belonging to OpenClaw
- `MANAGES` for stewardship or operational responsibility, with edge properties carrying the exact role
