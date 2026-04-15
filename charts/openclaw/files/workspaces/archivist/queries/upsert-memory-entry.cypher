// Idempotently create or refresh a graph node for one Qdrant memory packet.
// Required params: memory_slug, qdrant_id, document_sha256, summary.
// Optional params: agent, domain, kind, project, created, memory_ref, linked_at.

MERGE (memory:Entity:MemoryEntry {slug: $memory_slug})
SET memory.qdrant_id = $qdrant_id,
    memory.document_sha256 = $document_sha256,
    memory.summary = $summary,
    memory.agent = $agent,
    memory.domain = $domain,
    memory.kind = $kind,
    memory.project = $project,
    memory.created = $created,
    memory.memory_ref = $memory_ref,
    memory.linked_at = $linked_at,
    memory.name = coalesce($summary, $memory_slug)
RETURN memory.slug AS memory_slug, memory.qdrant_id AS qdrant_id, memory.document_sha256 AS document_sha256;
