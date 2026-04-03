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

## When to search

Search Qdrant at the start of every task. Concrete triggers:
- About to work on a repo or codebase -> search for conventions and prior decisions about it
- Received a handoff referencing a plan or spec -> search for it and related implementation notes
- About to make an implementation decision -> search for prior decisions on the same topic
- Need to find where code, docs, or reports were stored -> search for the artifact name or description

## When to store

Store a memory when any of these happen during your session:

1. **You produced an artifact.** Whenever you create or update repo code, open or land a commit, write implementation notes, produce a report, or store docs, specs, or plans in Nextcloud, store a memory noting what it is and where it lives. Include repo, branch, commit, or `nc_refs` when relevant.
2. **A decision was made.** Whenever implementation work resolves a technical question, establishes a convention, changes workflow, or chooses one approach over another, store it as a `[decision]` or `[convention]` memory.
3. **You learned something reusable.** Whenever you discover a reusable pattern, constraint, workaround, deployment detail, or repo-specific rule that would help future implementation work, store it.
4. **End-of-session review.** Before finishing a non-trivial session, review what you did and verify you stored memories for items 1-3 above. If you produced artifacts or decisions but did not store memories for them yet, do it now.

## Entity references

When storing a memory that involves known system entities (projects, services, agents, repos, people), mention them by their canonical graph slug in the memory text. Examples: `ai-homebase`, `nextcloud`, `coder`, `cluster-gitops`. This helps the archivist link your memories to graph entities during nightly grooming.

## Search tips

- Include domain tags in queries when useful: `[real] coder convention for ai-homebase helm charts`
- Be specific: `ai-homebase ingress naming decision` works better than `ingress`
- If a search returns nothing, try rephrasing; semantic search is sensitive to wording
- If results mix real and fictional content, re-query with an explicit `[real]` or `[fictional]` prefix
