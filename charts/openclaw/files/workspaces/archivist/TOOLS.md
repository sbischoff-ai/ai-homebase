# Tools

Local notes for this setup.

## Memgraph

- `mgconsole` is the standard client in this stack.
- Use `MEMGRAPH_HOST`, `MEMGRAPH_PORT`, or `MEMGRAPH_BOLT_URI` instead of hard-coding endpoints.
- Reusable Cypher entry points live under `queries/`.
- `state/grooming-cursor.json` is local workspace state for grooming passes.

## Files

- Files in this workspace, including `queries/` and `state/`, are local workspace files.
- `CURRENT.md`, `SURFACES.md`, and `daily/` are your local desk. Read them before non-trivial curation work.
- `/Desk/...` are Nextcloud remote paths for shared continuity and live indexing. Use them only to discover relevant supporting surfaces.
- `/Projects/...` are Nextcloud remote paths for supporting documentation, not your primary truth source.
- Keep `TOOLS.md` stable. Put active surface references in `SURFACES.md`, and let `/Desk/index.md` point to shared supporting docs when they matter outside your workspace.
- Seeded ai-homebase docs you will commonly reference:
  - `/Projects/ai-homebase/knowledge-graph-schema.md`
  - `/Projects/ai-homebase/qdrant-memory-schema.md`
  - `/Projects/ai-homebase/archivist-grooming-log.md`

## Sessions

- Return context maps and curation outcomes to `agent:main:main`.

## Notes

- Keep this file current when Memgraph connection variables, query-library conventions, or seeded schema references change.
