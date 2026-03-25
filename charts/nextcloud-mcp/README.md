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

## Secret patterns

The chart supports the repo-standard `existingSecret`, `envFromSecrets`, and `secretRefs[]` patterns for additional environment variables when needed.
In the platform stack's `multi_user_basic` posture, the pod uses `NEXTCLOUD_HOST` plus `ENABLE_MULTI_USER_BASIC_AUTH=true`; the dedicated `openclaw-nextcloud-mcp-secrets` Secret is for OpenClaw's Basic Auth header and Nextcloud bootstrap user, not for mounting into the MCP pod.
