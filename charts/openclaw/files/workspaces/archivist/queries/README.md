## Archivist Query Library

Use these query files as the default entry points for routine graph work.

- Prefer reusing and extending these files over writing one-off Cypher from scratch.
- Keep queries idempotent when they mutate canonical entities or relationships.
- Use `queries/run_query.py` for parameterized helpers so you do not have to hand-render Cypher literals. The same command should work unchanged from both the gateway and the archivist sandbox because the runtime injects `MEMGRAPH_HOST` and `MEMGRAPH_PORT`.

Examples:

```bash
python3 queries/run_query.py queries/entity-by-slug.cypher --params-json '{"slug":"ai-homebase"}'
python3 queries/run_query.py queries/project-service-agent-overview.cypher --params-json '{"project_slug":"ai-homebase"}'
python3 queries/run_query.py queries/upsert-memory-entry.cypher --params state/memory-entry-params.json
python3 queries/run_query.py queries/upsert-memory-entry.cypher --params state/memory-entry-params.json --dry-run
```

- `context-map.cypher`: Retrieves an entity and its full immediate neighborhood (one hop). Used by the structured recall mode to build context maps on demand.
- `upsert-memory-entry.cypher`: Creates or refreshes a `MemoryEntry` node from a normalized Qdrant packet.
- `link-memory-created-by-agent.cypher`: Connects a memory to the agent that stored or curated it.
- `link-project-memory.cypher`: Connects a project to a graph-promoted memory.
- `link-memory-to-entity.cypher`: Connects a memory to a selected entity as evidence.
- `link-memory-supersedes.cypher`: Connects append-only replacement memories to older memory nodes.
- `link-memory-tag.cypher`: Promotes durable Qdrant tags to `Concept` nodes.
- `unlinked-memory-entries.cypher`: Lists graph-promoted memories still missing entity evidence links.

`run_query.py` replaces `$param` placeholders with escaped Cypher literals from JSON. Missing parameters default to `null`; pass `--strict` when you want missing parameters to fail before execution.
