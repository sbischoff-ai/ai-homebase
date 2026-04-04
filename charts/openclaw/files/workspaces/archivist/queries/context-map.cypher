// Context map for a given entity slug.
// Usage: replace $slug with the target entity's slug value.
// Returns the entity, all directly connected entities, and the relationships between them.

MATCH (e:Entity {slug: $slug})
OPTIONAL MATCH (e)-[r_out]->(neighbor_out:Entity)
OPTIONAL MATCH (neighbor_in:Entity)-[r_in]->(e)
RETURN
  e.slug AS entity_slug,
  labels(e) AS entity_labels,
  e.name AS entity_name,
  e.domain AS entity_domain,
  e.status AS entity_status,
  collect(DISTINCT {
    direction: 'outgoing',
    type: type(r_out),
    role: r_out.role,
    kind: r_out.kind,
    target_slug: neighbor_out.slug,
    target_name: neighbor_out.name
  }) AS outgoing,
  collect(DISTINCT {
    direction: 'incoming',
    type: type(r_in),
    role: r_in.role,
    kind: r_in.kind,
    source_slug: neighbor_in.slug,
    source_name: neighbor_in.name
  }) AS incoming;
