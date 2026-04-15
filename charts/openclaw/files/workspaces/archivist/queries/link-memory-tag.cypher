// Link a MemoryEntry to a durable tag concept.
// Required params: memory_slug, tag_slug, tag_name.
// Optional params: confidence.

MATCH (memory:Entity:MemoryEntry {slug: $memory_slug})
MERGE (tag:Entity:Concept {slug: $tag_slug})
ON CREATE SET tag.name = $tag_name,
              tag.domain = 'real',
              tag.kind = 'tag'
MERGE (memory)-[rel:TAGGED_WITH]->(tag)
SET rel.confidence = $confidence,
    rel.context = 'Qdrant memory metadata tag'
RETURN memory.slug AS memory_slug, tag.slug AS tag_slug, type(rel) AS relationship;
