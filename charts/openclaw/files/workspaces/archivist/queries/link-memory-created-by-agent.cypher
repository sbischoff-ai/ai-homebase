// Link a MemoryEntry to the agent that stored or curated it.
// Required params: memory_slug, agent_slug.

MATCH (memory:Entity:MemoryEntry {slug: $memory_slug})
MATCH (agent:Entity:Agent {slug: $agent_slug})
MERGE (memory)-[rel:CREATED_BY {role: 'memory-agent'}]->(agent)
SET rel.context = 'Qdrant memory provenance'
RETURN memory.slug AS memory_slug, agent.slug AS agent_slug, type(rel) AS relationship;
