# Nextcloud MCP chart

This chart deploys the `nextcloud-mcp-server` companion service for a Nextcloud instance.

## Default posture

- Image pinned to `ghcr.io/cbcoutinho/nextcloud-mcp-server:0.65.3`
- HTTP service on port `8000`
- Default auth mode set by `authentication.mode`, with the platform stack using `multi_user_basic`
- Intended to sit behind a dedicated ingress hostname rather than a shared path

## Required values

- `nextcloud.url`: upstream Nextcloud base URL the MCP server should call
- `authentication.mode`: upstream deployment mode, for example `multi_user_basic`
- `command[]`: optional command override for the server launcher
- `enabledApps[]`: exact Nextcloud MCP app modules to expose

## Secret patterns

The chart supports the repo-standard `existingSecret`, `envFromSecrets`, and `secretRefs[]` patterns for additional environment variables when needed.
In the platform stack's `multi_user_basic` posture, the pod uses `NEXTCLOUD_HOST` plus `ENABLE_MULTI_USER_BASIC_AUTH=true`; the dedicated `openclaw-nextcloud-mcp-secrets` Secret is for OpenClaw's Basic Auth header and Nextcloud bootstrap user, not for mounting into the MCP pod.

## App filtering

The standard stack uses `enabledApps[]` to expose only:

- `notes`
- `webdav`
- `sharing`
- `tables`
- `calendar`

`Todos` come from the upstream `calendar` surface through CalDAV tasks support.

The chart intentionally launches the server through a small Python wrapper instead of the upstream `--enable-app` CLI flags because the published image currently contains the `sharing` app module but still rejects `--enable-app sharing` during Click validation.
