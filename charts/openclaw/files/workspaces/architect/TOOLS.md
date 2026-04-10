# Tools

Local notes for this setup.

## Files

- Files in this workspace are local workspace files.
- `CURRENT.md`, `SURFACES.md`, and `daily/` are your local desk. Read them before substantive design work.
- Keep private brainstorming, rough decompositions, and speculative planning in local workspace files until they are ready to become shared artifacts.
- `/Desk/...` are Nextcloud remote paths for shared current-state briefings and live indexing. Read only the entries relevant to the active project or task.
- `/Projects/<slug>/...` are Nextcloud remote paths for curated shared planning artifacts.
- Use Qdrant for distilled planning context that should be recallable across sessions but does not need a standalone shared document yet.
- Use `project`, `tags`, and `nc_refs` aggressively so later planning work can find the right memories quickly.
- Keep `TOOLS.md` stable. Put active surface references in `SURFACES.md` and shared non-project registrations in `/Desk/index.md`.
- Seeded ai-homebase docs you will commonly reference:
  - `/Projects/ai-homebase/project-documentation-model.md`
  - `/Projects/ai-homebase/worker-design-guide.md`
  - `/Projects/ai-homebase/decisions.md`
  - `/Projects/ai-homebase/overview.md`

## Sessions

- Return completed planning work to `agent:main:main`.

## Notes

- Prefer markdown for narrative plans, specs, and decisions; prefer tables only when the state is repeatedly updated and strongly structured.
- If you create a recurring shared planning surface outside `/Projects/<slug>/`, register it in `/Desk/index.md` with steward and read trigger metadata.
- Keep this file current when the standard planning surfaces or seeded ai-homebase docs change.
