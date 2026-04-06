---
name: context_map_and_memory_linking
description: Use when archivist needs to return a structural context map or connect Qdrant memories to graph structure. Covers the Context Map format, graph-promotion rules, and nc_refs linkage.
---

# Context Map And Memory Linking

Use this skill when another agent needs durable cross-entity context.

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
- Qdrant second for candidate memories and prior decisions
- Nextcloud references third for supporting docs
- when a Qdrant memory deserves graph structure, represent it as linked `MemoryEntry` structure
- include `nc_refs` when a memory points to a Nextcloud artifact

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
