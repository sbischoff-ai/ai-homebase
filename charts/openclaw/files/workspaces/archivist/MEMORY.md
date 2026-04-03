# Memory - Archivist Agent

All six agents share one Qdrant collection for durable semantic memory.

Search Qdrant before graph edits and use Memgraph traversal before storing new graph facts.

Store durable ontology choices, graph schema decisions, canonical entity mappings, reusable query patterns, cross-domain relationship knowledge, and knowledge-import conventions.

Do not store secrets, transient task state, or redundant graph dumps.

Every stored memory must use this text format:
`[domain] [kind] Complete statement here.`

Every stored memory must include metadata with at least:
`{"kind": "...", "domain": "...", "agent": "archivist", "created": "ISO-8601"}`

## When to search

Search Qdrant before any graph or memory operation. Concrete triggers:
- About to create or update graph entities -> search for related memories and prior schema decisions
- Starting a grooming pass -> search for recent memories to evaluate
- Asked about knowledge structure -> search for prior schema and ontology decisions
- Need to locate stored artifacts or knowledge sources -> search for the project, entity, or artifact name first

## When to store

Store a memory when any of these happen during your session:

1. **You produced an artifact.** Whenever you create or update schema notes, graph guidance, import reports, grooming summaries, or other durable knowledge artifacts, store a memory noting what it is and where it lives. Include `nc_refs` for Nextcloud paths when relevant.
2. **A decision was made.** Whenever curation work resolves an entity mapping, ontology choice, schema rule, import convention, or graph operating mode, store it as a `[decision]` or `[convention]` memory.
3. **You learned something reusable.** Whenever you discover a reusable relationship pattern, query strategy, disambiguation rule, or memory-curation heuristic that would help future sessions, store it.
4. **End-of-session review.** Before finishing a non-trivial session, review what you did and verify you stored memories for items 1-3 above. If you produced artifacts or decisions but did not store memories for them yet, do it now.

## Search tips

- Include domain tags in queries when useful: `[decision] graph schema for ai-homebase projects`
- Be specific: `archivist canonical entity mapping for OpenClaw agents` works better than `entities`
- If a search returns nothing, try rephrasing; semantic search is sensitive to wording
- If results mix real and fictional content, re-query with an explicit `[real]` or `[fictional]` prefix
