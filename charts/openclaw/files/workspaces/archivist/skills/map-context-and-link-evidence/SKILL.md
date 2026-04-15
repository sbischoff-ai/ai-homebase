---
name: map-context-and-link-evidence
description: Use this to answer "what do we know about this?" with a Memgraph-first context map and link relevant Qdrant memories as graph evidence.
---

# Context Map And Memory Linking

Use when asked for durable cross-entity context.

## Context Map Format

```markdown
## Context Map: <entity or topic>

### Entity
- Slug: <slug>
- Labels: <graph labels>
- Domain: <real | fictional | speculative>
- Status: <active | archived | other>

### Relationships
- <relationship> -> <connected entity> (role: <role>, kind: <kind>)

### Linked Memories
- [<kind>] <memory summary> (agent: <agent>, created: <date>)

### Nextcloud References
- <path> - <brief description>

### Summary
<2-3 sentence synthesis>
```

## Linking Rules

- Memgraph first for relationships
- Qdrant exact lookup second when Memgraph has `MemoryEntry.qdrant_id`: run `python3 qdrant/get_memory.py "<point-id>"`
- Qdrant MCP semantic search only when graph traversal is sparse or the entity is unknown
- shared Nextcloud `/Desk/` cues and Nextcloud references third for supporting docs
- when a Qdrant memory deserves graph structure, represent it as linked `MemoryEntry` structure with slug `qdrant:<point_id>`
- include `nc_refs` when a memory points to a Nextcloud artifact
- after successful Memgraph linking, annotate the Qdrant point with `python3 qdrant/set_graph_link.py`

## General Archivist Return Format

Use this when the task is curation work but not primarily a context-map response:

```markdown
## Handoff Complete
**Task:** <brief restatement>
**Status:** <complete | partial - needs X | blocked - needs Y>

### Deliverables
- Memgraph: <nodes, edges, schema or query updates>
- Qdrant: <memories stored, linked, groomed>
- Nextcloud: <paths updated, if any>

### For the user
<concise explanation of what durable context was added or clarified>

### Follow-up needed
<which agent should do what next>
```
