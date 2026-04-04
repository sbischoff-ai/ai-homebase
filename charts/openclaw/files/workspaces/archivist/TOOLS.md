Use Memgraph, Qdrant, and Nextcloud together to maintain the long-term knowledge system.

Memgraph runtime:
- Use `mgconsole` as the canonical Memgraph client from both gateway and sandbox sessions.
- Connection target: use `${MEMGRAPH_HOST}:${MEMGRAPH_PORT}` or `${MEMGRAPH_BOLT_URI}`.
- Memgraph Lab UI is the human-friendly browser companion, but your canonical write path is Cypher through `mgconsole`.
- Reusable query files belong in this workspace under `queries/`.

`mgconsole` guidance:
- Inspect connectivity with `printf 'RETURN 1;\\n' | mgconsole --host "$MEMGRAPH_HOST" --port "$MEMGRAPH_PORT" --output-format csv`.
- Run checked query files with `mgconsole --host "$MEMGRAPH_HOST" --port "$MEMGRAPH_PORT" --output-format csv < queries/<name>.cypher`.
- Start from the seeded query library and extend it instead of rewriting common Cypher from scratch.
- Prefer `MERGE` over `CREATE` for idempotent canonical entities and relationships.
- For structured recall requests, start with `queries/context-map.cypher` and then enrich the result with Qdrant and Nextcloud only where the graph leaves ambiguity or points to supporting documents.

Retrieval order:
- Traverse Memgraph first for answers, structure, and entity relationships.
- Check Qdrant only to discover likely entities, slugs, prior decisions, or candidate memory nodes that should inform graph traversal.
- Check Nextcloud only when the graph points to a document or when you need an authoritative documented entry point.
- Do not answer graph questions directly from Qdrant or Nextcloud when Memgraph can answer them.
- When building a context map, keep the Memgraph one-hop neighborhood as the backbone and use Qdrant and Nextcloud to fill recall gaps, not to replace graph structure.

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
- Use Qdrant to improve graph search, not to replace it.

Qdrant filtering:
- Use the `query_filter` parameter on `qdrant-find` to filter by metadata.
- All memories include `created` (ISO-8601), `kind`, `domain`, `agent` in metadata.
- To find recent memories for grooming, filter by `created` date:
  query_filter: {"must": [{"key": "created", "range": {"gte": "YYYY-MM-DDT00:00:00Z"}}]}
  Replace the date with yesterday's date or the relevant time window.
- Combine filters with semantic queries for targeted grooming (e.g., find recent decisions about a specific project).

Nextcloud coordination:
- Treat any path under `/Projects/` or `/Notes/` as a Nextcloud remote path, not a local filesystem path.
- For those paths, use only Nextcloud tools whose names start with `nc_webdav_`.
- Never use shell commands, local file APIs, workspace file tools, or local path assumptions on `/Projects/...` or `/Notes/...`.
- Never create a local directory or local file that mirrors a Nextcloud path.
- If a parent directory is missing, create it in Nextcloud with an `nc_webdav_*` tool, then read or write the file in Nextcloud with an `nc_webdav_*` tool.
- Read `/Projects/ai-homebase/knowledge-graph-schema.md` and related project docs before changing the canonical schema with `nc_webdav_*` tools.
- Update durable schema and query notes there when the canonical model changes with `nc_webdav_*` tools.
- Use Nextcloud to keep human-readable graph guidance stable and shareable through `nc_webdav_*` tools.

Nightly grooming:
- Inspect recent or weakly linked Qdrant memories.
- Inspect relevant Nextcloud project docs for durable entities and relationships not yet reflected in Memgraph with `nc_webdav_*` tools.
- Add missing graph structure conservatively and record important schema/query changes durably.
