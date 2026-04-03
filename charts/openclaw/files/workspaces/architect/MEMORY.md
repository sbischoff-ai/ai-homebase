# Memory - Architect Agent

All six agents share one Qdrant collection for durable semantic memory.

Search Qdrant before planning, designing, or specifying work that may have prior decisions, tradeoffs, or project history.
Escalate to archivist when the design depends on stable entity relationships, large durable context maps, or graph-backed recall.

Store durable design knowledge such as architecture decisions, rationale, planning patterns, conventions, constraints, and cross-project dependencies.

Do not store full design documents, scratch notes, or task trackers in Qdrant. Keep durable documents in `/Projects/<slug>/` and working notes in `/Notes/<slug>/`.

Every stored memory must use this text format:
`[domain] [kind] Complete statement here.`

Every stored memory must include metadata with at least:
`{"kind": "...", "domain": "...", "agent": "architect", "created": "ISO-8601"}`

When a memory points to Nextcloud content, include the reference in both the text and `nc_refs` metadata.

Existing seeded project:
- `ai-homebase` already exists in Nextcloud.
- Durable project docs live in `/Projects/ai-homebase/`.
- Working notes live in `/Notes/ai-homebase/`.
- Treat that project as the standing documentation and planning home for the cluster itself.

## When to search

Search Qdrant at the start of every planning or design task. Concrete triggers:
- About to design or plan something -> search for prior designs, decisions, and constraints
- Asked to review or revisit a plan -> search for the original plan and follow-up decisions
- Working on a project that has history -> search for the project name and related decisions
- Need to find where a spec, note, or design artifact was stored -> search for the artifact name or topic

## When to store

Store a memory when any of these happen during your session:

1. **You produced an artifact.** Whenever you create or update a spec, architecture note, plan, tradeoff analysis, roadmap, or other durable design output, store a memory noting what it is and where it lives. Include `nc_refs` for Nextcloud paths.
2. **A decision was made.** Whenever planning work resolves a question, establishes a convention, chooses a design direction, or changes operating assumptions, store it as a `[decision]` or `[convention]` memory.
3. **You learned something reusable.** Whenever you discover a reusable constraint, dependency, planning pattern, rationale, or cross-project relationship that will matter again, store it.
4. **End-of-session review.** Before finishing a non-trivial session, review what you did and verify you stored memories for items 1-3 above. If you produced artifacts or decisions but did not store memories for them yet, do it now.

## Search tips

- Include domain tags in queries when useful: `[decision] ai-homebase deployment architecture`
- Be specific: `architect rationale for shared project docs location` works better than `docs`
- If a search returns nothing, try rephrasing; semantic search is sensitive to wording
- If results mix real and fictional content, re-query with an explicit `[real]` or `[fictional]` prefix
