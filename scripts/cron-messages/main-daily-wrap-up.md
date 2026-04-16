Run the daily wrap-up for main in the user-day that is ending now.

Execution rules:
- Treat `CURRENT.md`, `SURFACES.md`, and `daily/` as local workspace files.
- Treat Nextcloud `/Desk/current.md`, Nextcloud `/Desk/index.md`, and Nextcloud `/Desk/daily/` as Nextcloud remote paths.
- Use only `nc_webdav_*` tools for the Nextcloud `/Desk/...` paths.
- Do not use local filesystem tools on the Nextcloud `/Desk/...` paths.

Steps:
1. Read local `CURRENT.md` and `SURFACES.md`.
2. If Nextcloud `/Desk/` already exists and shared continuity is active, read Nextcloud `/Desk/current.md` and the latest relevant shared daily note.
3. Create or update local `daily/YYYY-MM-DD.md` for the day that is ending now.
4. Write that local daily file as a short historical wrap-up in past tense. Do not copy local `CURRENT.md` verbatim.
5. Make the local daily file clearly historical by covering:
   - what coordination work happened that day
   - what cross-agent or user-relevant state still mattered afterward
   - what was explicitly carried forward
6. Rewrite local `CURRENT.md` for the new current day, preserving its section structure but carrying forward only still-open concerns, recent developments that still matter, upcoming commitments, open loops, and useful retrieval cues.
7. If shared continuity is active, create Nextcloud `/Desk/`, Nextcloud `/Desk/current.md`, Nextcloud `/Desk/index.md`, and Nextcloud `/Desk/daily/README.md` first when they are missing.
8. Create or update Nextcloud `/Desk/daily/YYYY-MM-DD.md` for the same day with a compact historical shared wrap-up in past tense when shared continuity is active.
9. Rewrite Nextcloud `/Desk/current.md` so it carries forward only still-relevant cross-agent or user-relevant current state when shared continuity is active.

Boundaries:
- Keep both daily notes compact.
- Do not copy either current-state file verbatim into a daily note.
- Do not move private local-only material into shared Nextcloud `/Desk/`.
