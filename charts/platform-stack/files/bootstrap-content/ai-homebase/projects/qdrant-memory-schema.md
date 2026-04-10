# Qdrant Semantic Memory Schema

This document defines the shared OpenClaw memory contract for the Qdrant MCP server.

Summary:
- all agents share one Qdrant collection for durable semantic memory;
- retrieval is currently semantic, so text prefixes are part of the contract;
- metadata is still required for auditability, cleanup, and future filtering.

Required metadata:
- `kind`
- `domain`
- `agent`
- `created`

Optional metadata:
- `confidence`
- `project`
- `nc_refs`
- `tags`
- `supersedes`
- `expiry`
- `source_url`

Stable kind vocabulary:
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

Stable domain vocabulary:
- `real`
- `speculative`
- `fictional`
- `synthetic`

Required text format:
- `[domain] [kind] Complete self-contained statement.`

Guidance:
- brief from local desk notes and shared `/Desk/` continuity first, then query Qdrant from those cues;
- use `project`, `tags`, `expiry`, and `nc_refs` to keep retrieval targeted;
- store durable knowledge, not transient status;
- do not store secrets;
- use `fictional` for creative content;
- include Nextcloud references in both text and `nc_refs` when relevant.
