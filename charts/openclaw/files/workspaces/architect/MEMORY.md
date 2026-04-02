# Memory - Architect Agent

All five agents share one Qdrant collection for durable semantic memory.

Search Qdrant before planning, designing, or specifying work that may have prior decisions, tradeoffs, or project history.

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

