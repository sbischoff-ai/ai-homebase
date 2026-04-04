MATCH (memory:Entity:MemoryEntry)-[rel]-(entity:Entity)
WHERE memory.slug = $memory_slug OR memory.qdrant_id = $qdrant_id
RETURN
  memory.slug AS memory_slug,
  memory.qdrant_id AS qdrant_id,
  type(rel) AS relationship,
  entity.slug AS entity_slug,
  labels(entity) AS entity_labels,
  entity.name AS entity_name
ORDER BY entity_slug;
