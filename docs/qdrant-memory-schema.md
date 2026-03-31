# Qdrant Semantic Memory Schema

This document defines the repo-managed memory contract for the shared OpenClaw Qdrant collection.

## Summary

All four OpenClaw agents share one Qdrant collection for durable semantic memory. The `qdrant-find` tool currently relies on semantic retrieval, so the stored text itself must carry the structural signals needed to separate factual, speculative, and creative memories.

Metadata remains required for auditability, later filtering, and cleanup, but text prefixes are part of the retrieval contract today.

## Required metadata

Every `qdrant-store` call must include a `metadata` object with:

- `kind`: memory category
- `domain`: reality domain
- `agent`: one of `main`, `coder`, `architect`, `watchdog`
- `created`: ISO 8601 timestamp such as `2026-03-31T10:00:00Z`

## Optional metadata

- `confidence`: `high`, `medium`, or `low`
- `project`: project slug such as `ai-homebase`
- `nc_refs`: array of Nextcloud references
- `tags`: 1 to 4 short free-form tags
- `supersedes`: short description of replaced memory
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
[domain] [kind] Complete self-contained statement.
```

Examples:

```text
[real] [decision] OpenClaw agents use a single shared Qdrant collection with domain and kind prefixes in stored text.
[fictional] [creative] In the Ironvale story, Commander Hask leads the northern garrison and reports to the Regent.
[speculative] [plan] Proposed migration path: move Nextcloud from SQLite to PostgreSQL in Q2 with a short downtime window.
```

Rules:

- Prefix tags are lowercase and bracket-wrapped.
- The summary after the tags must be a complete statement, not a fragment.
- If the memory is project-specific, include the project name naturally in the text.
- If the memory corrects a prior memory, mention that in both the text and `supersedes`.
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

## Future filtering

The schema is designed to support later metadata filtering for at least:

- `kind`
- `domain`
- `agent`

That future change should be additive. The current retrieval contract still depends on the text prefixes above.
