// Link a replacement memory to the older MemoryEntry it supersedes.
// Required params: new_memory_slug, old_memory_slug.

MATCH (new_memory:Entity:MemoryEntry {slug: $new_memory_slug})
MATCH (old_memory:Entity:MemoryEntry {slug: $old_memory_slug})
MERGE (new_memory)-[rel:DERIVED_FROM {kind: 'supersedes'}]->(old_memory)
SET rel.context = 'Append-only Qdrant memory correction'
RETURN new_memory.slug AS new_memory_slug, old_memory.slug AS old_memory_slug, type(rel) AS relationship;
