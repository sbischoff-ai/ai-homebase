{{WORKER_TOOLS_INSTRUCTIONS}}

Default surface rules:
- local workspace files use `read`, `edit`, `write`, `apply_patch`
- local commands use `exec`, `process`
- Nextcloud paths are remote paths and use only Nextcloud tools
- Qdrant tools are used only if the worker definition explicitly says so

Put detailed workflow procedures in `skills/` instead of expanding this file.
