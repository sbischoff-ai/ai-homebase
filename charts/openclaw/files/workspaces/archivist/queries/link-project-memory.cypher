// Link a project to a graph-promoted Qdrant memory.
// Required params: project_slug, memory_slug.

MATCH (project:Entity:Project {slug: $project_slug})
MATCH (memory:Entity:MemoryEntry {slug: $memory_slug})
MERGE (project)-[rel:HAS_PART {kind: 'memory'}]->(memory)
SET rel.context = 'Graph-promoted Qdrant memory'
RETURN project.slug AS project_slug, memory.slug AS memory_slug, type(rel) AS relationship;
