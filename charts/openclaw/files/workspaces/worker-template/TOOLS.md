# Tools

Local notes for this worker setup.

{{WORKER_TOOLS_INSTRUCTIONS}}

## Files

- Local workspace files live in this worker workspace.
- Use local workspace files for private execution state and temporary scratch work.
- `CURRENT.md`, `SURFACES.md`, and `daily/` are optional local continuity surfaces when this worker runs across sessions.
- `/Projects/...` are Nextcloud remote paths when this worker is allowed to use them.
- `/Desk/...` are shared Nextcloud continuity and index paths only when this worker is explicitly allowed to use them.
- Use Qdrant only when the worker definition explicitly grants that memory surface.

## Sessions

- Standard return target: `agent:main:main`

## Notes

- Record concrete setup facts here: paths, IDs, hosts, schedules, and other worker-specific tool notes.
- Keep volatile active-surface references in `SURFACES.md`, not here.
- Keep this file current when those local notes change.
