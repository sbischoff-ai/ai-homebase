// Link a MemoryEntry to one relevant entity selected by archivist.
// Required params: memory_slug, entity_slug.
// Optional params: context, confidence.

MATCH (memory:Entity:MemoryEntry {slug: $memory_slug})
MATCH (entity:Entity {slug: $entity_slug})
MERGE (memory)-[rel:RELATES_TO {kind: 'memory-evidence'}]->(entity)
SET rel.context = $context,
    rel.confidence = $confidence
RETURN memory.slug AS memory_slug, entity.slug AS entity_slug, type(rel) AS relationship;
