# Memory - Main

This deployment uses Qdrant as the durable shared semantic memory layer. Archivist plus Memgraph handles long-horizon curation and graph structure.

Use this file only for local retrieval hints and recurring lookup notes. Do not treat it as the primary long-term memory store.

## Search

Use `qdrant-find` before non-trivial coordination when:
- the user has ongoing project history
- a prior decision might exist
- a specialist handoff would benefit from recalled context
- a user preference may already be known

## Store

Use `qdrant-store` for:
- durable user preferences
- project-level decisions
- stack rules and operating conventions
- durable artifact summaries

Format memories as concise complete statements. Include metadata with at least:
`kind`, `domain`, `agent`, `created`

When a memory corresponds to Nextcloud content, include `nc_refs`.
