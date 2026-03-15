# Services reference

This document summarizes each service's role, default posture, toggle, and integration notes.

Profile-specific defaults can differ from base chart defaults; verify effective behavior via values layering in [`docs/configuration.md`](./configuration.md#values-hierarchy-lowest-to-highest-precedence).

## Composition overview

### Core plane

| Service | Role | Default expectation |
| --- | --- | --- |
| `openclaw` | General AI assistant UI/API | Enabled with private service access by default (`ingress.enabled: false` in baseline and shipped overlays) |
| `openhands` | Agentic coding UI/API | Enabled with profile-specific ingress posture: baseline/AKS/prod keep ingress off; dev/k3d enable ingress for local workflows |

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

- General AI assistant service for user-facing chat/API use.
- Exposed via ingress when enabled.
- Requires secret references for API/auth integrations.

### OpenHands

- Agentic coding service that provides a user-facing UI/API.
- Ingress behavior is profile-specific: base chart defaults to private (`openhands.ingress.enabled: false`), local overlays (`values-dev.yaml`, `values-k3d.yaml`) can enable ingress, and AKS/prod overlays keep ingress off unless explicitly enabled by environment overlays.
- Tune isolation/scheduling/persistence independently from OpenClaw.

## Optional service details

### Nextcloud

- Stateful user data service.
- Ingress is enabled by default so the UI/API is reachable when the service is enabled.
- Plan for larger and growing PVC usage.

### Gitea

- Source control service with persistent repositories.
- Shipped profiles keep `gitea.service.type: ClusterIP` and configure ingress for internal-only access (`className: internal-nginx`, host `gitea.vpn.homebase.internal`).
- Intended access path is VPN-first: user connects through wg-easy/WireGuard, then reaches the internal Gitea hostname.
- Avoid public DNS annotations for Gitea unless your annotation targets a private-only DNS zone.
- Ensure backup for repository integrity.
- Official-chart dependency defaults in shipped overlays use in-cluster PostgreSQL + Redis (`gitea.postgresql.enabled=true`, `gitea.redis.enabled=true`, `gitea.postgresql-ha.enabled=false`) with `gitea.gitea.config.database.DB_TYPE=postgres` to avoid SQLite drift.
- Size and storage class for Gitea app data and PostgreSQL data should follow the active profile storage conventions (`gitea.persistence.*` and `gitea.postgresql.primary.persistence.*`).

### Paperless-ngx

- Multi-volume document pipeline (`data`, `media`, etc.).
- Ingress is enabled by default so the UI/API is reachable when the service is enabled.
- Validate storage growth and retention behavior.

### Infisical

- Optional in-cluster secret-management component based on upstream standalone chart semantics.
- Primary knobs are grouped under `infisical.infisical`, `infisical.ingress`, `infisical.postgresql`, and `infisical.redis`.
- Uses `infisical.infisical.kubeSecretRef` to point at the runtime/bootstrap secret.
- Can coexist with external secret-provider patterns.

### wg-easy

- Provides VPN lifecycle UI and WireGuard endpoint.
- UI/API ingress is enabled by default when the service is enabled.
- VPN endpoint exposure should be tightly controlled.
- Container-level `securityContext` is configurable and defaults to adding `NET_ADMIN` and `SYS_MODULE` capabilities required by WireGuard.

## Secret contract model (all services)

Supported patterns:

- `existingSecret` for a primary Secret source (OpenClaw uses explicit `secretKeys.*` mappings against this Secret).
- `envFromSecrets[]` for additional bulk Secret imports.
- `secretRefs[]` for explicit key-to-env mapping.
- `secretEnv[]` for structured key-to-env mapping rendered as `valueFrom.secretKeyRef`.

Infisical integration is done by syncing provider values into Kubernetes Secret names consumed by each chart (for example `openhands-app-secrets`) and then referencing those names via `existingSecret`, `envFromSecrets`, `secretRefs`, or `secretEnv`.

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
