// MemoryEntry nodes that have not yet been connected to durable graph structure.

MATCH (memory:Entity:MemoryEntry)
WHERE NOT (memory)-[:RELATES_TO {kind: 'memory-evidence'}]->(:Entity)
RETURN
  memory.slug AS memory_slug,
  memory.qdrant_id AS qdrant_id,
  memory.agent AS agent,
  memory.domain AS domain,
  memory.kind AS kind,
  memory.project AS project,
  memory.created AS created,
  memory.summary AS summary
ORDER BY memory.created DESC, memory.slug
LIMIT 100;
