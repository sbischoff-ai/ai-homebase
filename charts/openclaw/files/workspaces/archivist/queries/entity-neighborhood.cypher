MATCH (entity:Entity {slug: $slug})-[rel]-(neighbor:Entity)
RETURN
  type(rel) AS relationship,
  properties(rel) AS relationship_props,
  labels(neighbor) AS neighbor_labels,
  neighbor.slug AS neighbor_slug,
  neighbor.name AS neighbor_name,
  neighbor.kind AS neighbor_kind
ORDER BY relationship, neighbor_slug;
