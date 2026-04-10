Run the daily wrap-up for archivist in the user-day that is ending now.

Use local workspace file tools for `CURRENT.md`, `SURFACES.md`, `daily/`, `queries/`, and `state/` as needed.

Steps:
1. Read `CURRENT.md` and `SURFACES.md`.
2. Create or update `daily/YYYY-MM-DD.md` for the day that is ending now.
3. Write that daily file as a short historical wrap-up in past tense. Do not copy `CURRENT.md` verbatim.
4. Make the daily file clearly historical by covering:
   - what curation, linkage, or schema work happened that day
   - which unresolved entities, cleanup loops, or query hints still mattered afterward
   - what was explicitly carried forward
5. Rewrite `CURRENT.md` for the new current day, preserving its section structure but carrying forward only still-open curation threads, recent changes that still matter, open loops, and useful retrieval cues.

Boundaries:
- Keep the daily note compact.
- Do not replace durable Memgraph or Qdrant state with a diary entry.
- Do not leave resolved curation work in `CURRENT.md`.
