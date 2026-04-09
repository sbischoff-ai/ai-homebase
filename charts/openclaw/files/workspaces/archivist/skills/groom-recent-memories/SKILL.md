---
name: groom-recent-memories
description: Use when archivist is running a memory grooming, deduplication, or curation pass. Covers the last-successful-grooming cursor, recency-scoped Qdrant search, bootstrap behavior, and when to advance the cursor.
---

# Recent Memory Grooming

Use this when running a periodic memory grooming, deduplication, or curation pass.

## Cursor State

- Read the last successful grooming boundary from `state/grooming-cursor.json`.
- The cursor file must contain `last_successful_grooming` as an ISO-8601 timestamp or `null`.
- Treat this file as runtime state, not as a prose note.

## Procedure

1. Read `state/grooming-cursor.json` before searching Qdrant.
2. If `last_successful_grooming` is present, search only for candidate memories newer than that timestamp.
3. If `last_successful_grooming` is `null`, do a bootstrap pass over a bounded recent window instead of an unbounded historical search.
4. Groom, deduplicate, merge, or link only the candidate memories returned by that recency-scoped search.
5. If the pass produces durable semantic outcomes, store them in Qdrant using the standard archivist memory rules.
6. If a groomed memory deserves graph structure, update Memgraph and link it through the existing `MemoryEntry` rules.
7. Advance `last_successful_grooming` only after the grooming pass completes successfully.
8. If the pass aborts, fails, or leaves the work incomplete, do not change the cursor.

## Bootstrap Window

- A first-run bootstrap pass should stay bounded to recent history.
- Prefer the smallest recent window that still captures ungroomed backlog for the active task.
- Do not run an unbounded full-history search unless main explicitly asks for historical backfill.

## Return Notes

- Report the effective grooming window in the handoff to main.
- Include whether the cursor was advanced.
- Include any durable Qdrant or Memgraph changes.
