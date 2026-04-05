## Archivist Query Library

Use these query files as the default entry points for routine graph work.

- Prefer reusing and extending these files over writing one-off Cypher from scratch.
- Keep queries idempotent when they mutate canonical entities or relationships.
- Use `MEMGRAPH_HOST` and `MEMGRAPH_PORT` with `mgconsole` for execution. The same command should work unchanged from both the gateway and the archivist sandbox because the runtime injects the correct reachable endpoint.

Examples:

```bash
mgconsole --host "$MEMGRAPH_HOST" --port "$MEMGRAPH_PORT" --output-format csv < queries/entity-by-slug.cypher
mgconsole --host "$MEMGRAPH_HOST" --port "$MEMGRAPH_PORT" --output-format csv < queries/project-service-agent-overview.cypher
```

- `context-map.cypher`: Retrieves an entity and its full immediate neighborhood (one hop). Used by the structured recall mode to build context maps on demand.
