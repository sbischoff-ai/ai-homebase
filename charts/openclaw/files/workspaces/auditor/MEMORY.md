# Memory - Auditor Agent

All six agents share one Qdrant collection for durable semantic memory.

Search Qdrant before any review of requirements, implementations, conventions, or prior findings that may have historical context.

Store durable audit knowledge such as findings patterns, review criteria, recurring anti-patterns, systemic observations, and resolved quality risks.

Do not store full reports, raw evidence dumps, transient review notes, or issues that are only local to one unfinished pass. Keep durable reports in `/Projects/<slug>/`.

Every stored memory must use this text format:
`[domain] [kind] Complete statement here.`

Every stored memory must include metadata with at least:
`{"kind": "...", "domain": "...", "agent": "auditor", "created": "ISO-8601"}`

When a memory points to Nextcloud audit reports or review artifacts, include the reference in both the text and `nc_refs` metadata.

## When to search

Search Qdrant before any review. Concrete triggers:
- Starting a review -> search for prior audit findings on the same area
- Evaluating a plan or implementation -> search for the original requirements and prior decisions
- Looking for recurring patterns -> search for past audit observations and anti-patterns
- Need to find where an audit report or evidence artifact was stored -> search for the project, requirement, or artifact name

## When to store

Store a memory when any of these happen during your session:

1. **You produced an artifact.** Whenever you create or update an audit report, review note, risk summary, or other durable review artifact, store a memory noting what it is and where it lives. Include `nc_refs` for Nextcloud paths when relevant.
2. **A decision was made.** Whenever a review resolves a question, confirms a requirement interpretation, establishes a quality convention, or changes audit posture, store it as a `[decision]` or `[convention]` memory.
3. **You learned something reusable.** Whenever you discover a recurring finding pattern, anti-pattern, systemic weakness, or effective review heuristic that would help future audits, store it.
4. **End-of-session review.** Before finishing a non-trivial session, review what you did and verify you stored memories for items 1-3 above. If you produced artifacts or decisions but did not store memories for them yet, do it now.

## Search tips

- Include domain tags in queries when useful: `[decision] audit requirement interpretation for ai-homebase`
- Be specific: `auditor recurring anti-pattern in helm values layering` works better than `anti-patterns`
- If a search returns nothing, try rephrasing; semantic search is sensitive to wording
- If results mix real and fictional content, re-query with an explicit `[real]` or `[fictional]` prefix
