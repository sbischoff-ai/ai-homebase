# Services reference

This document summarizes each service's role, default posture, toggle, and integration notes.

## Composition overview

### Core plane

| Service | Role | Default expectation |
| --- | --- | --- |
| `openclaw` | Control-plane API/UI | Enabled and externally reachable via ingress |
| `openhands` | Execution runtime/workers | Enabled and internal-only (`ClusterIP`) |

### Optional personal-cloud services

| Service | Toggle | Typical use |
| --- | --- | --- |
| `nextcloud` | `nextcloud.enabled` | File sync/collaboration |
| `gitea` | `gitea.enabled` | Git hosting |
| `paperless-ngx` | `paperlessNgx.enabled` | Document ingestion/archive |
| `infisical` | `infisical.enabled` | Secret-management service |
| `wg-easy` | `wgEasy.enabled` | VPN management and private access |

## Core plane details

### OpenClaw

- Primary external endpoint for platform clients.
- Should be treated as the only default public ingress.
- Requires secret references for API/auth integrations.

### OpenHands

- Consumes execution work; manages runtime workspaces.
- Keep internal unless a reviewed internal-ingress pattern is required.
- Tune isolation/scheduling/persistence independently from OpenClaw.

## Optional service details

### Nextcloud

- Stateful user data service.
- Ingress should be enabled only when user-facing access is required.
- Plan for larger and growing PVC usage.

### Gitea

- Source control service with persistent repositories.
- Optional ingress for developer access.
- Ensure backup for repository integrity.

### Paperless-ngx

- Multi-volume document pipeline (`data`, `media`, etc.).
- Optional ingress depending on user workflow.
- Validate storage growth and retention behavior.

### Infisical

- Optional in-cluster secret-management component.
- Can coexist with external secret-provider patterns.
- Keep exposure private/admin-scoped.

### wg-easy

- Provides VPN lifecycle UI and WireGuard endpoint.
- UI should remain private; VPN endpoint exposure should be tightly controlled.
- Avoid default public UI publishing.

## Secret contract model (all services)

Supported patterns:

- `existingSecret` for importing all keys from one Secret.
- `secretRefs[]` for explicit key-to-env mapping.

Recommended naming:

- Secret names: `kebab-case`.
- Secret keys/env vars: `UPPER_SNAKE_CASE`.

## Placeholder and hardening notes

The chart values intentionally leave these unresolved for operators:

- Actual queue backend and credentials.
- External secret provider mappings.
- Final per-service network policies.
- Production SLO/SLI and alerting definitions.

Treat these as required environment work before production promotion.
