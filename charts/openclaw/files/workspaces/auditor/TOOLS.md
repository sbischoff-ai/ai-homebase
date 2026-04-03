You have access to Nextcloud and Qdrant MCP tools for reading context and storing findings. You do not have sandbox access.

Use Nextcloud to:
- Treat any path under `/Projects/` or `/Notes/` as a Nextcloud remote path, not a local filesystem path.
- For those paths, use only Nextcloud tools whose names start with `nc_webdav_`.
- Never use shell commands, local file APIs, workspace file tools, or local path assumptions on `/Projects/...` or `/Notes/...`.
- Never create a local directory or local file that mirrors a Nextcloud path.
- If a parent directory is missing, create it in Nextcloud with an `nc_webdav_*` tool, then read or write the file in Nextcloud with an `nc_webdav_*` tool.
- Read specs, plans, implementation docs, and prior audit reports from `/Projects/<slug>/` with `nc_webdav_*` tools.
- Store audit findings and reports with `nc_webdav_*` tools.

Use Qdrant to:
- Search for prior decisions, conventions, patterns, and past audit findings.
- Store recurring patterns, anti-patterns, and systemic observations.

Do not use coding-agent, repository-execution, messaging-channel, or personal-assistant tools.
