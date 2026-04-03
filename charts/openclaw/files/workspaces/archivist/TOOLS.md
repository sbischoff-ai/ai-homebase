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
- The canonical schema uses a compact set of reusable labels and relationships.
- **Node labels:** Entity (base), Person, Agent, Organization, Place, Thing, Concept, Event, Work, Project, Service, Collection, MemoryEntry.
- **Relationships:** RELATES_TO, HAS_PART, INFLUENCES, LOCATED_IN, CREATED_BY, DERIVED_FROM, OCCURS_IN, TAGGED_WITH.
- Push domain-specific meaning into properties (`role`, `kind`, `context`) instead of creating new labels or relationships.
- Example: "Alice is the DM of the Ashenmoor campaign" -> Campaign -[:HAS_PART {role: "dungeon-master"}]-> Alice, not a custom RUNS_CAMPAIGN relationship.
- Example: "Coder maintains the gitops repo" -> Coder -[:INFLUENCES {kind: "maintains"}]-> cluster-gitops, not a custom MAINTAINS relationship.
- Every node must have `Entity` label, a `slug` property, and a `domain` property (real/fictional/speculative/synthetic).
- Read `/Projects/ai-homebase/knowledge-graph-schema.md` for the full canonical schema before making changes.
- Only add a new label if the concept requires structurally different traversal patterns. Only add a new relationship if it has genuinely different traversal semantics from the existing set.

Qdrant coordination:
- Other agents may store ordinary memories directly.
- You own grooming, consolidation, deduplication patterns, and graph-linking of durable memories.
- When a Qdrant memory deserves graph structure, create or update a `MemoryEntry` node and connect it to the relevant entities.

Qdrant filtering:
- Use the `query_filter` parameter on `qdrant-find` to filter by metadata.
- All memories include `created` (ISO-8601), `kind`, `domain`, `agent` in metadata.
- To find recent memories for grooming, filter by `created` date:
  query_filter: {"must": [{"key": "created", "range": {"gte": "YYYY-MM-DDT00:00:00Z"}}]}
  Replace the date with yesterday's date or the relevant time window.
- Combine filters with semantic queries for targeted grooming (e.g., find recent decisions about a specific project).

Nextcloud coordination:
- Read `/Projects/ai-homebase/knowledge-graph-schema.md` and related project docs before changing the canonical schema.
- Update durable schema and query notes there when the canonical model changes.
- Use Nextcloud to keep human-readable graph guidance stable and shareable.

Nightly grooming:
- Inspect recent or weakly linked Qdrant memories.
- Inspect relevant Nextcloud project docs for durable entities and relationships not yet reflected in Memgraph.
- Add missing graph structure conservatively and record important schema/query changes durably.
