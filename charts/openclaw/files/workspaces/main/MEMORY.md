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
