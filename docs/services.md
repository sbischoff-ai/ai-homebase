# Services reference

This document summarizes each service's role, default posture, toggle, and integration notes.

## Composition overview

### Core plane

| Service | Role | Default expectation |
| --- | --- | --- |
| `openclaw` | Control-plane API/UI | Enabled and externally reachable via ingress |
| `openhands` | Agentic coding UI/API | Enabled and exposed via ingress |

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
- Exposed via ingress when enabled.
- Requires secret references for API/auth integrations.

### OpenHands

- Agentic coding service that provides a user-facing UI/API.
- Exposed via ingress when enabled.
- Tune isolation/scheduling/persistence independently from OpenClaw.

## Optional service details

### Nextcloud

- Stateful user data service.
- Ingress is enabled by default so the UI/API is reachable when the service is enabled.
- Plan for larger and growing PVC usage.

### Gitea

- Source control service with persistent repositories.
- Ingress is enabled by default so developer UI/API access is available when the service is enabled.
- Ensure backup for repository integrity.

### Paperless-ngx

- Multi-volume document pipeline (`data`, `media`, etc.).
- Ingress is enabled by default so the UI/API is reachable when the service is enabled.
- Validate storage growth and retention behavior.

### Infisical

- Optional in-cluster secret-management component.
- Can coexist with external secret-provider patterns.
- Ingress is enabled by default when the service is enabled; restrict access in environment overlays when needed.

### wg-easy

- Provides VPN lifecycle UI and WireGuard endpoint.
- UI/API ingress is enabled by default when the service is enabled.
- VPN endpoint exposure should be tightly controlled.

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
