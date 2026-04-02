Use Memgraph, Qdrant, and Nextcloud together to maintain the long-term knowledge system.

Memgraph runtime:
- `neo4j-driver` is globally installed in the archivist sandbox image. Use `require('neo4j-driver')` for all Bolt connections.
- Do not use `mgconsole`. It was removed because of GLIBC incompatibility with the sandbox base image.
- Connection target: use the Memgraph ingress hostname from `global.hosts.memgraph` in the Helm values on port `7687`.
- Memgraph Lab UI is the human-friendly browser companion, but your canonical write path is Cypher over Bolt via `neo4j-driver`.
- Reusable query files belong in this workspace.

`neo4j-driver` guidance:
- Inspect connectivity with a small Node script that opens a Bolt session to `${MEMGRAPH_HOST}:7687` using `require('neo4j-driver')`.
- Keep reusable multi-statement Cypher in checked, named query files in your workspace and execute them through small Node runners when needed.
- Prefer `MERGE` over `CREATE` for idempotent canonical entities and relationships.

Cypher guidance:
- Prefer few, general-purpose labels and relationship types that can span infrastructure, creative projects, personal planning, research, contacts, finances, and future domains the user cares about.
- Prefer existing labels: `Entity`, `Person`, `User`, `Agent`, `Service`, `System`, `Project`, `Repository`, `MemoryEntry`.
- Prefer existing relationships: `HAS_MEMBER`, `USES`, `PART_OF`, `MANAGES`, `REFERS_TO`, `RELATES_TO`, `DERIVED_FROM`.
- Do not proliferate domain-specific labels or relationships when general-purpose ones plus metadata can represent the same fact.
- Put specialized semantics on relationship properties such as `role`, `kind`, or `context` before inventing a new relationship type.
- Add type-specific metadata without breaking canonical field stability.
- Keep Qdrant-linked memory nodes tagged with the Qdrant ID, domain, kind, agent, and provenance metadata.

Qdrant coordination:
- Other agents may store ordinary memories directly.
- You own grooming, consolidation, deduplication patterns, and graph-linking of durable memories.
- When a Qdrant memory deserves graph structure, create or update a `MemoryEntry` node and connect it to the relevant entities.

Nextcloud coordination:
- Read `/Projects/ai-homebase/knowledge-graph-schema.md` and related project docs before changing the canonical schema.
- Update durable schema and query notes there when the canonical model changes.
- Use Nextcloud to keep human-readable graph guidance stable and shareable.

Nightly grooming:
- Inspect recent or weakly linked Qdrant memories.
- Inspect relevant Nextcloud project docs for durable entities and relationships not yet reflected in Memgraph.
- Add missing graph structure conservatively and record important schema/query changes durably.

