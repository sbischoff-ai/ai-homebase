MATCH (entity:Entity)
WHERE entity.slug = $slug
RETURN labels(entity) AS labels, entity.slug AS slug, entity.name AS name, entity.kind AS kind, entity.domain AS domain;
