# Qdrant Semantic Memory Schema

This document defines the repo-managed memory contract for the shared OpenClaw Qdrant collection.

## Summary

The bootstrapped OpenClaw agents share one Qdrant collection for durable semantic memory. The `qdrant-find` tool currently relies on semantic retrieval, so the stored text itself must carry the structural signals needed to separate factual, speculative, and creative memories.

Metadata remains required for auditability, filtering, and cleanup, but it does not improve vector ranking by itself. Any term that should help semantic recall must also appear naturally in the stored `information` text.

## Required metadata

Every `qdrant-store` call must include a `metadata` object with:

- `kind`: memory category
- `domain`: reality domain
- `agent`: one of `main`, `coder`, `architect`, `archivist`, `watchdog`, `auditor`
- `created`: ISO 8601 timestamp such as `2026-03-31T10:00:00Z`

## Optional metadata

- `confidence`: `high`, `medium`, or `low`
- `project`: project slug such as `ai-homebase`
- `nc_refs`: array of Nextcloud references
- `tags`: 1 to 4 short free-form tags
- `supersedes`: short description of an older memory that this new append-only memory replaces or corrects
- `expiry`: ISO 8601 timestamp for staleness handling
- `source_url`: external source URL

## Stable kind vocabulary

- `user-preference`
- `user-context`
- `decision`
- `convention`
- `pattern`
- `fact`
- `plan`
- `task-context`
- `incident`
- `monitor-rule`
- `creative`
- `relationship`
- `reference`

## Stable domain vocabulary

- `real`: verified or high-confidence real-world information
- `speculative`: plans, hypotheses, or unverified claims
- `fictional`: creative writing, worldbuilding, or roleplay content
- `synthetic`: generated examples, templates, or test data

## Required information text format

Every stored `information` string must use this shape:

```text
[domain] [kind] Complete self-contained retrieval-optimized statement.
```

Examples:

```text
[real] [decision] In project ai-homebase, OpenClaw agents use a single shared Qdrant collection with domain and kind prefixes in stored memory text.
[fictional] [creative] In the Ironvale story, Commander Hask leads the northern garrison and reports to the Regent.
[speculative] [plan] For project ai-homebase, proposed Nextcloud migration path: move from SQLite to PostgreSQL in Q2 with a short downtime window.
```

Rules:

- Prefix tags are lowercase and bracket-wrapped.
- The summary after the tags must be a complete statement, not a fragment.
- Store one durable claim per memory. Split unrelated decisions, facts, preferences, or incidents into separate memories.
- Use 1 to 3 compact sentences. Do not store multi-topic summaries, raw command output, or whole document digests as one memory.
- If the memory is project-specific, include the project slug or project name naturally in the text.
- Include natural retrieval anchors when relevant: service or component names, agent or person names, artifact paths, common aliases, incident names, and source references.
- Do not rely on metadata-only terms for recall. If a future query should match a term, put that term in `information`.
- If the memory corrects or replaces a prior memory, create a new memory that mentions the correction in both the text and `supersedes`.
- Qdrant MCP is append-only in this stack: agents cannot update, delete, merge, or mark existing Qdrant points with the current `qdrant-store` and `qdrant-find` tools.
- `archivist` has separate seeded Qdrant REST scripts for graph-link grooming. Those scripts may recover point IDs and set a top-level `graph` payload, but they must not create semantic memories, modify vectors, or overwrite MCP-managed `document` or `metadata`.
- If the memory points to Nextcloud content, include the identifier or path naturally in the text.

## Nextcloud references

Use `nc_refs` when a memory points back to a Nextcloud artifact.

Each item may include:

- `type`: `file`, `note`, `calendar-event`, `todo`, `table`, or `directory`
- `id`: stable ID or UID when available
- `path`: path for file or directory references
- `label`: human-readable description

Guidance:

- Prefer stable IDs over paths when both exist.
- File and directory paths are acceptable when no stable ID exists.
- Include the same reference in both `information` text and `nc_refs` metadata when practical.

## Retrieval guidance

Agents should brief themselves from their local desk and the shared `/Desk/` continuity surfaces first, then query Qdrant from those cues.

Guidance:

- prefer recency-scoped searches guided by active project slugs, people, services, and open loops
- use `project` whenever the memory belongs to a project slug
- use `tags` for discoverability across future work
- use `expiry` for short-lived current-context memories that should stop shaping recall after the near term
- use `nc_refs` whenever a memory points to a Nextcloud artifact or shared surface
- combine semantic query terms with metadata filters for project, domain, kind, agent, and recency when possible
- do not treat orientation work as a blind memory dump

The upstream Qdrant MCP server stores user-provided metadata under the `metadata` payload object. Use nested payload keys in `query_filter`, for example:

```json
{"must": [{"key": "metadata.created", "range": {"gte": "2026-04-02T00:00:00Z"}}]}
{"must": [{"key": "metadata.agent", "match": {"value": "coder"}}]}
{"must": [{"key": "metadata.domain", "match": {"value": "real"}}, {"key": "metadata.kind", "match": {"value": "decision"}}, {"key": "metadata.project", "match": {"value": "ai-homebase"}}]}
{"must": [{"key": "metadata.tags", "match": {"value": "qdrant"}}]}
```

## Storage guidance

Store durable knowledge that should influence future agent behavior:

- user preferences and context
- architecture and policy decisions
- conventions and reusable patterns
- incidents and resolutions
- monitoring rules
- durable project context
- creative material that must remain clearly separated from real-world recall

Do not store:

- secrets or credentials
- ephemeral task status
- transient command output
- live metrics snapshots
- information easily re-derived from the repo or current system state

Short-term continuity that only needs to survive the next run belongs in local desk notes or shared `/Desk/` surfaces instead of Qdrant.

## Append-only corrections

The current Qdrant MCP tool surface can only search and store memories. It cannot mutate existing points. To correct, split, or consolidate prior memories:

- use `qdrant-find` to recover the old memory text and metadata
- store one or more new atomic replacement memories with `supersedes` metadata describing the older memory
- mention in the new `information` text that it replaces or corrects the prior memory
- do not claim that the old Qdrant entry was edited, deleted, merged, or marked

Old entries may still appear in future search results. Treat a result as stale when a newer returned memory clearly supersedes it.

## Future filtering

The schema supports metadata filtering through nested payload keys:

- `metadata.kind`
- `metadata.domain`
- `metadata.agent`
- `metadata.project`
- `metadata.created`
- `metadata.tags`

The current retrieval contract still depends on the text prefixes and natural-language anchors above because vector ranking only embeds the `information` text.
