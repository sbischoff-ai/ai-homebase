# Qdrant Semantic Memory Schema

This document defines the shared OpenClaw memory contract for the Qdrant MCP server.

## Summary

- all agents share one Qdrant collection for durable semantic memory
- retrieval ranks the embedded `information` text, so text prefixes and natural anchors matter
- metadata is required for auditability, filtering, and grooming, but metadata alone does not improve vector ranking
- ordinary search and storage use `qdrant-find` and `qdrant-store`
- `archivist` has separate Qdrant REST scripts only for graph-link grooming

## Required Metadata

- `kind`
- `domain`
- `agent`
- `created`

Optional metadata:

- `confidence`
- `project`
- `nc_refs`
- `tags`
- `supersedes`
- `expiry`
- `source_url`

Stable kind vocabulary:

- `user-preference`
- `user-context`
- `decision`
- `convention`
- `pattern`
- `fact`
- `plan`
- `task-context`
- `incident`
- `monitor-rule`
- `creative`
- `relationship`
- `reference`

Stable domain vocabulary:

- `real`
- `speculative`
- `fictional`
- `synthetic`

## Required Text Format

`[domain] [kind] Complete self-contained retrieval-optimized statement.`

Rules:

- store one atomic durable claim per memory
- use 1 to 3 compact sentences
- include natural anchors such as project slug, service/component, agent/person, artifact path, aliases, and source reference when relevant
- include important recall terms in `information`, not only in metadata
- do not store multi-topic summaries, raw command output, transient status, secrets, or easily re-derived information
- include Nextcloud references in both text and `nc_refs` when relevant

## Filtering

Qdrant MCP stores memory metadata under nested payload keys:

- `metadata.kind`
- `metadata.domain`
- `metadata.agent`
- `metadata.project`
- `metadata.created`
- `metadata.tags`

Combine semantic query terms with metadata filters when project, domain, kind, agent, or recency is known.

## Archivist Graph Grooming

Qdrant MCP is append-only for normal agents: existing points cannot be updated, deleted, merged, or marked with `qdrant-store` and `qdrant-find`.

For graph grooming only, `archivist` may use the seeded `qdrant/` scripts to recover point IDs and set a top-level `graph` payload after Memgraph `MemoryEntry` links are written. These scripts must not create semantic memories, modify vectors, or overwrite MCP-managed `document` or `metadata`.
