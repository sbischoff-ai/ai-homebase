# Tools

Use this template to define the tool and skill instructions for the worker you are creating. Distinguish the worker's local workspace files from any remote Nextcloud paths the worker is allowed to use.

{{WORKER_TOOLS_INSTRUCTIONS}}

## Files

- Local workspace files live in this worker workspace.
- Use local workspace files for private execution state and temporary scratch work.
- `CURRENT.md`, `SURFACES.md`, and `daily/` are optional custom continuity surfaces when this worker keeps state across runs.
- Nextcloud `/Projects/...` are remote paths when this worker is allowed to use them.
- Nextcloud `/Desk/...` are shared continuity and index paths only when this worker is explicitly allowed to use them.
- Use local workspace file tools only for local workspace files such as `CURRENT.md`, `SURFACES.md`, `daily/`, and other files in this worker workspace.
- Use Nextcloud tools only for Nextcloud `/Projects/...` and Nextcloud `/Desk/...` paths.
- Creating or editing a local workspace file does not create or update a Nextcloud file.
- Creating or editing a Nextcloud file does not create or update a local workspace file.
- Local workspace directories and Nextcloud directories are separate storage systems, not mirrored views of the same path.
- Do not use local filesystem tools on Nextcloud paths, and do not use Nextcloud tools on local workspace files.
- Use Qdrant only when the worker definition explicitly grants that memory surface.

## Sessions

- Standard return target: `agent:main:main`

## Notes

- Record concrete setup facts here: paths, IDs, hosts, schedules, and other worker-specific tool notes.
- Keep volatile active-surface references in `SURFACES.md`, not here.
- Keep this file current when those local notes change.
