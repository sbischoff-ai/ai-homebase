MERGE (source:Entity {slug: $source_slug})
ON CREATE SET source.name = $source_name, source.domain = $source_domain, source.kind = $source_kind
MERGE (target:Entity {slug: $target_slug})
ON CREATE SET target.name = $target_name, target.domain = $target_domain, target.kind = $target_kind
MERGE (source)-[rel:RELATES_TO {kind: $relationship_kind}]->(target)
SET rel.context = $relationship_context
RETURN source.slug AS source_slug, target.slug AS target_slug, type(rel) AS relationship;
