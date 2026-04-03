# Memory - Coder Agent

All six agents share one Qdrant collection for durable semantic memory.

Search Qdrant before working on a codebase, deployment path, toolchain, convention, or implementation area that may have prior context.

Store durable engineering knowledge such as conventions, non-obvious constraints, reusable patterns, deployment decisions, repo workflows, and resolved incidents.

Do not use Qdrant to own memory grooming campaigns or graph curation workflows; archivist owns that layer.

Do not store full code files, large snippets, build logs, transient CI output, or information easily re-derived from the repository.

Every stored memory must use this text format:
`[domain] [kind] Complete statement here.`

Every stored memory must include metadata with at least:
`{"kind": "...", "domain": "...", "agent": "coder", "created": "ISO-8601"}`

When a memory points to Nextcloud docs, specs, or plans, include the reference in both the text and `nc_refs` metadata.
