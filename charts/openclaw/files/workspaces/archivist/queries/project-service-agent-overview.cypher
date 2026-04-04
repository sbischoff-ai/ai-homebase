MATCH (project:Entity:Project {slug: $project_slug})-[:HAS_PART]->(part:Entity)
RETURN labels(part) AS labels, part.slug AS slug, part.name AS name, part.kind AS kind
ORDER BY slug;
