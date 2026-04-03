# Memory - Watchdog Agent

All six agents share one Qdrant collection for durable semantic memory.

Search Qdrant before setting monitoring rules, investigating incidents, or defining escalation behavior that may have prior history.

Store durable monitoring knowledge such as baselines, thresholds, escalation patterns, recurring failure signatures, and incident resolutions.

Do not store current system state, live metrics, routine all-clear checks, or single health-check results unless they reveal a reusable pattern.

Every stored memory must use this text format:
`[domain] [kind] Complete statement here.`

Every stored memory must include metadata with at least:
`{"kind": "...", "domain": "...", "agent": "watchdog", "created": "ISO-8601"}`

## When to search

Search Qdrant before any monitoring decision. Concrete triggers:
- Investigating an anomaly -> search for prior incidents with similar symptoms
- About to set or change a baseline -> search for existing baselines and monitoring rules
- Escalating an issue -> search for prior escalations of the same type
- Need to find where an incident note, rule, or report was stored -> search for the service, symptom, or artifact name

## When to store

Store a memory when any of these happen during your session:

1. **You produced an artifact.** Whenever you create or update an incident report, baseline note, escalation guide, monitoring rule document, or durable triage artifact, store a memory noting what it is and where it lives. Include `nc_refs` for Nextcloud paths when relevant.
2. **A decision was made.** Whenever monitoring work resolves a threshold, baseline, escalation path, incident classification, or operating rule, store it as a `[decision]` or `[convention]` memory.
3. **You learned something reusable.** Whenever you discover a recurring failure signature, triage pattern, baseline insight, or mitigation rule that would help future monitoring, store it.
4. **End-of-session review.** Before finishing a non-trivial session, review what you did and verify you stored memories for items 1-3 above. If you produced artifacts or decisions but did not store memories for them yet, do it now.

## Entity references

When storing a memory that involves known system entities (projects, services, agents, repos, people), mention them by their canonical graph slug in the memory text. Examples: `ai-homebase`, `nextcloud`, `coder`, `cluster-gitops`. This helps the archivist link your memories to graph entities during nightly grooming.

## Search tips

- Include domain tags in queries when useful: `[decision] watchdog baseline for ai-homebase cluster health`
- Be specific: `watchdog recurring paperless startup failure signature` works better than `paperless issue`
- If a search returns nothing, try rephrasing; semantic search is sensitive to wording
- If results mix real and fictional content, re-query with an explicit `[real]` or `[fictional]` prefix
