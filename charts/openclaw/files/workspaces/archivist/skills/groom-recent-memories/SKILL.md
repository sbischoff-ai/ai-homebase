---
name: groom-recent-memories
description: Use for weekly, nightly-watchdog, impromptu, or targeted memory grooming that must process Qdrant/Nextcloud deltas and checkpoint progress.
---

# Recent Memory Grooming

Use when running a periodic or requested memory grooming, deduplication, graph-linking, or curation pass.

## Checkpoint State

- Read `state/grooming-checkpoint.json` before any search, scan, or update.
- Supported triggers are `weekly`, `nightly-watchdog`, `impromptu`, and `targeted`.
- Treat `last_successful_grooming` as the default Qdrant memory delta boundary.
- Treat `last_successful_graph_link` as the graph-link catch-up boundary.
- Treat `last_weekly_grooming` and `last_triggered_grooming` as cadence markers, not replacements for the successful delta boundaries.
- Track Nextcloud metadata under `nextcloud.surfaces` as `{etag,last_modified,size,checked_at}` when the WebDAV tools expose those fields.
- Treat this file as runtime state, not as a prose note.

## Procedure

1. Read `state/grooming-checkpoint.json` and assign a compact run ID such as `groom-YYYYMMDD-HHMMSS`.
2. Identify the trigger:
   - `weekly`: scheduled weekly graph grooming.
   - `nightly-watchdog`: watchdog sent a scored activity trigger with reason codes.
   - `impromptu`: user or another agent requested grooming without a special scope.
   - `targeted`: the request names a project, entity, source, or since-window.
3. Choose the Qdrant window:
   - default to `last_successful_grooming`.
   - use `last_successful_graph_link` for graph-link catch-up.
   - for `weekly`, also inspect recent/unlinked points since `last_weekly_grooming` when present.
4. Run `python3 qdrant/scroll_memories.py --since "<cursor>" --limit <n> --out state/qdrant-candidates.jsonl` when a cursor exists. If the cursor is `null`, do a bounded recent bootstrap pass instead of an unbounded historical search.
5. Scan Nextcloud only for registered high-value surfaces from `SURFACES.md`, Nextcloud `/Desk/index.md`, and current ai-homebase project docs. Compare WebDAV metadata against `nextcloud.surfaces`, and read content only for changed surfaces or paths named in a watchdog/user trigger.
6. Review the normalized Qdrant packets and changed Nextcloud surfaces. Groom, deduplicate, split, supersede, or link only candidates in the effective delta.
7. If the pass produces durable semantic outcomes, store replacement memories through `qdrant-store` using the standard archivist memory rules.
8. If a groomed memory deserves graph structure, create or update the Memgraph `MemoryEntry` and links with the `queries/` helpers through `python3 queries/run_query.py ...`.
9. After Memgraph succeeds, run `python3 qdrant/set_graph_link.py --point-id "<point-id>" ...` to annotate only the Qdrant top-level `graph` payload.
10. Append exactly one row to Nextcloud `/Projects/ai-homebase/archivist-grooming-log.md` with completed time, run ID, trigger, window, reason codes, Qdrant count, Nextcloud surface count, Memgraph changes, checkpoint summary, and issues.
11. Advance `state/grooming-checkpoint.json` with `python3 grooming/update_checkpoint.py ...` only after the grooming pass, Memgraph updates, Qdrant graph annotations, and grooming-log row complete successfully.
12. If the pass aborts, fails, or leaves work incomplete, record the issue in the grooming log and do not advance successful checkpoint timestamps.

Qdrant MCP is append-only here: `qdrant-store` adds a new entry, and there is no update, delete, merge, or mark operation for existing points. When splitting or consolidating overloaded memories, store new atomic replacement memories with `supersedes` metadata that describes the older memory text returned by `qdrant-find`; do not claim the old Qdrant entry was changed. Merge only by storing a new consolidated memory when the result remains one durable claim with clear retrieval anchors.

The archivist-only `qdrant/` scripts may read point IDs and set the top-level `graph` payload for linkage bookkeeping. They must not create semantic memories, modify vectors, or overwrite MCP-managed `document` or `metadata`.

## Bootstrap And Delta Windows

- A first-run bootstrap pass should stay bounded to recent history.
- Prefer the smallest recent window that still captures ungroomed backlog for the active task.
- Do not run an unbounded full-history search unless main explicitly asks for historical backfill.
- If an impromptu request does not specify scope, use the checkpoint delta.
- If a targeted request specifies project, entity, source, or since-window, constrain the pass to that scope but still update the checkpoint only after a successful run.

## Return Notes

- Report the effective grooming window in the handoff to main.
- Include whether the checkpoint was advanced.
- Include any durable Qdrant or Memgraph changes.
