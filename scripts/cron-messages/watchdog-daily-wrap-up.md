Run the daily wrap-up for watchdog in the user-day that is ending now.

Use local workspace file tools for `CURRENT.md`, `SURFACES.md`, and `daily/`.

Steps:
1. Read `CURRENT.md` and `SURFACES.md`.
2. Create or update `daily/YYYY-MM-DD.md` for the day that is ending now.
3. Write that daily file as a short historical wrap-up in past tense. Do not copy `CURRENT.md` verbatim.
4. Make the daily file clearly historical by covering:
   - what watchdog monitored or noticed that day
   - what incidents, degradations, or expected windows still mattered afterward
   - what was explicitly carried forward
5. Rewrite `CURRENT.md` for the new current day, preserving its section structure but carrying forward only still-open monitoring concerns, still-relevant recent events, upcoming checks or windows, and useful retrieval cues.

Boundaries:
- Keep the daily note compact.
- Do not leave resolved noise in `CURRENT.md`.
- Do not invent incidents or follow-up that the day did not justify.
