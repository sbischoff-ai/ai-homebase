# Memory - Main Agent

All six agents share one Qdrant collection for durable semantic memory.

Search Qdrant before answering questions about user preferences, prior decisions, established conventions, people, relationships, project history, or anything that may have been discussed before.

Store durable coordination knowledge such as user preferences, user context, shared decisions, useful patterns, and resolved incidents.

Do not store calendar events, reminders, todos, shared files, ephemeral task state, or secrets. Put user-facing artifacts in Nextcloud instead.

Every stored memory must use this text format:
`[domain] [kind] Complete statement here.`

Every stored memory must include metadata with at least:
`{"kind": "...", "domain": "...", "agent": "main", "created": "ISO-8601"}`

When a memory points to Nextcloud content, include the reference in both the text and `nc_refs` metadata. Prefer stable IDs over paths when available.

## When to search

Search Qdrant at the start of every substantive interaction. Concrete triggers:
- User asks about something discussed before -> search for the topic
- About to delegate to a specialist -> search for prior work on that topic
- User references a project, person, or decision -> search for it
- Returning to a task after time has passed -> search for recent context

## When to store

Store a memory when any of these happen during your session:

1. **You produced an artifact.** Whenever you create, update, move, or share a durable artifact such as a Nextcloud note, project doc, report, or coordination file, store a memory noting what it is and where it lives. Include `nc_refs` for Nextcloud paths or stable IDs.
2. **A decision was made.** Whenever a conversation produces a decision, resolved question, user preference, new convention, routing rule, or change in operating mode, store it as a `[decision]`, `[preference]`, or `[convention]` memory.
3. **You learned something reusable.** Whenever you discover reusable context about the user, collaborators, projects, workflows, or coordination patterns that would help in a future session, store it.
4. **End-of-session review.** Before finishing a non-trivial session, review what you did and verify you stored memories for items 1-3 above. If you produced artifacts or decisions but did not store memories for them yet, do it now.

## Search tips

- Include domain tags in queries when useful: `[real] user's preferred editor` or `[decision] database choice for ai-homebase`
- Be specific: `main routing rule for ai-homebase infra work` works better than `routing`
- If a search returns nothing, try rephrasing; semantic search is sensitive to wording
- If results mix real and fictional content, re-query with an explicit `[real]` or `[fictional]` prefix
