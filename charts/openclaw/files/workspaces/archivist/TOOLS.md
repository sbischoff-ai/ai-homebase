# Tools

Local notes for this setup.

## Memgraph

- `mgconsole` is the standard client in this stack.
- Use `MEMGRAPH_HOST`, `MEMGRAPH_PORT`, or `MEMGRAPH_BOLT_URI` instead of hard-coding endpoints.
- Reusable Cypher entry points and the `queries/run_query.py` parameter helper live under `queries/`.
- `state/grooming-checkpoint.json` is the canonical local workspace checkpoint for grooming passes.
- Use `grooming/update_checkpoint.py` to patch the checkpoint instead of hand-editing JSON.

## Qdrant

- Use `qdrant-find` and `qdrant-store` for ordinary semantic memory search and storage.
- Use `QDRANT_URL`, `QDRANT_COLLECTION`, and optional `QDRANT_API_KEY` only with the archivist scripts in `qdrant/`.
- The `qdrant/` scripts recover point IDs, produce normalized JSONL, and annotate top-level `graph` payload linkage without changing vectors, `document`, or `metadata`.

## Files

- Files in this workspace, including `queries/` and `state/`, are local workspace files.
- `CURRENT.md`, `SURFACES.md`, and `daily/` are custom local continuity surfaces for active curation work.
- Nextcloud `/Desk/...` are remote paths for shared continuity and live indexing. Use them only to discover relevant supporting surfaces.
- Nextcloud `/Projects/...` are remote paths for supporting documentation, not your primary truth source.
- Keep `TOOLS.md` stable. Put active surface references in `SURFACES.md`, and let Nextcloud `/Desk/index.md` point to shared supporting docs when they matter outside your workspace.
- Seeded ai-homebase docs you will commonly reference:
  - Nextcloud `/Projects/ai-homebase/knowledge-graph-schema.md`
  - Nextcloud `/Projects/ai-homebase/qdrant-memory-schema.md`
  - Nextcloud `/Projects/ai-homebase/archivist-grooming-log.md`

## Sessions

- Return context maps and curation outcomes to `agent:main:main`.

## Notes

- Keep this file current when Memgraph connection variables, query-library conventions, or seeded schema references change.
