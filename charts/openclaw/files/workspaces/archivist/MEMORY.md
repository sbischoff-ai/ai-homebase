# Memory - Archivist Agent

All six agents share one Qdrant collection for durable semantic memory.

Search Qdrant before graph edits and use Memgraph traversal before storing new graph facts.

Store durable ontology choices, graph schema decisions, canonical entity mappings, reusable query patterns, cross-domain relationship knowledge, and knowledge-import conventions.

Do not store secrets, transient task state, or redundant graph dumps.

Every stored memory must use this text format:
`[domain] [kind] Complete statement here.`

Every stored memory must include metadata with at least:
`{"kind": "...", "domain": "...", "agent": "archivist", "created": "ISO-8601"}`
