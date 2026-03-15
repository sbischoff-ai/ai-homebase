# Services reference

This document summarizes each service's role, default posture, toggle, and integration notes.

Profile-specific defaults can differ from base chart defaults; verify effective behavior via values layering in [`docs/configuration.md`](./configuration.md#values-hierarchy-lowest-to-highest-precedence).

## Composition overview

### Core plane

| Service | Role | Default expectation |
| --- | --- | --- |
| `openclaw` | General AI assistant UI/API | Enabled with private service access by default (`ingress.enabled: false` in baseline and shipped overlays) |
| `openhands` | Agentic coding UI/API | Optional core-plane companion service with profile-specific ingress posture: baseline/AKS/prod keep ingress off; dev/k3d may enable ingress for local workflows |

### Default-on platform services

Minimum baseline for this stack is `openclaw`, `infisical`, and `wgEasy`; other services remain environment-selectable via overlays.

| Service | Toggle | Typical use |
| --- | --- | --- |
| `infisical` | `infisical.enabled` | Central secret-management service |
| `wg-easy` | `wgEasy.enabled` | WireGuard VPN management and private access |

### Optional personal-cloud services

| Service | Toggle | Typical use |
| --- | --- | --- |
| `nextcloud` | `nextcloud.enabled` | File sync/collaboration |
| `gitea` | `gitea.enabled` | Git hosting |
| `paperless-ngx` | `paperlessNgx.enabled` | Document ingestion/archive |

## Core plane details

### OpenClaw

- General AI assistant service for user-facing chat/API use.
- Exposed via ingress when enabled.
- Requires secret references for API/auth integrations.

### OpenHands

- Agentic coding service that provides a user-facing UI/API.
- Ingress behavior is profile-specific: base chart defaults to private (`openhands.ingress.enabled: false`), local overlays (`values-dev.yaml`, `values-k3d.yaml`) can enable ingress, and AKS/prod overlays keep ingress off unless explicitly enabled by environment overlays.
- Tune isolation/scheduling/persistence independently from OpenClaw.

## Service details

### Nextcloud

- Stateful user data service deployed as the standard `nextcloud:<tag>-apache` container in a `StatefulSet`, with a dedicated cron `CronJob` (`nextcloud.cron.*`) running `php -f /var/www/html/cron.php` against the same data volume.
- Baseline chart default for `nextcloud.persistence.size` is `100Gi`; overlays should size up (or intentionally down for constrained local/dev profiles) based on expected data growth.
- Public exposure posture is **dedicated-host only**: publish Nextcloud on `cloud.<domain>` with TLS and `/` path routing; do not publish under a shared subpath (for example `/cloud`) due to WebDAV/public-link/mobile-client compatibility risks.
- For homelab public exposure, keep non-Nextcloud services on internal ingress classes/hosts reachable through wg-easy/WireGuard while exposing only `cloud.<domain>` publicly.
- Canonical external backend wiring uses structured keys: `nextcloud.externalDatabase.{host,port,database,user,passwordSecret.*}` and `nextcloud.externalRedis.{host,port,passwordSecret.*}`, rendered to `POSTGRES_*` and `REDIS_*` container env vars.
- Required credential contracts should be set explicitly via:
  - `nextcloud.admin.passwordSecret.{name,key}` -> `NEXTCLOUD_ADMIN_PASSWORD`
  - `nextcloud.externalDatabase.passwordSecret.{name,key}` -> `POSTGRES_PASSWORD`
  - `nextcloud.externalRedis.passwordSecret.{name,key}` -> `REDIS_HOST_PASSWORD` (when Redis auth is enabled)
- Optional SMTP auth uses `nextcloud.smtp.passwordSecret.{name,key}` -> `SMTP_PASSWORD`.
- Supports bootstrap/runtime env wiring for `NEXTCLOUD_ADMIN_USER`, `NEXTCLOUD_ADMIN_PASSWORD`, `NEXTCLOUD_TRUSTED_DOMAINS`, `OVERWRITEPROTOCOL`, `PHP_MEMORY_LIMIT`, `PHP_UPLOAD_LIMIT`, `NEXTCLOUD_INIT_HTACCESS`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_NAME`, `SMTP_PASSWORD`, `MAIL_FROM_ADDRESS`, and `MAIL_DOMAIN`.
- Cron pods inherit the same database/redis env wiring and compatibility secret injection (`existingSecret`, `secretRefs[]`) as the main workload.
- `nextcloud.initialApps[]` optionally installs/enables apps via a Nextcloud entrypoint post-install hook; recommended optional apps are `calendar`, `contacts`, `tasks`, `notes`, `deck`, and `twofactor_totp`.
- `nextcloud.trustedDomains` accepts either a YAML list or a string (comma- or space-delimited). Always include the canonical `cloud.<domain>` hostname used by ingress.
- Compatibility secret injection patterns (`nextcloud.existingSecret`, `nextcloud.secretRefs[]`) remain supported for additional app/runtime secrets.
- Upgrade policy: move one Nextcloud major version at a time and take both external PostgreSQL backups and Nextcloud PVC snapshots before each major step; verify restore before continuing.
- Optional `nextcloud.networkPolicy.*` values render a default-deny `NetworkPolicy` for Nextcloud pods, allowing only ingress-controller traffic to the app port and required egress for DNS, PostgreSQL, Redis, and optional SMTP.

### Gitea

- Source control service with persistent repositories.
- Shipped profiles keep `gitea.service.type: ClusterIP` and configure ingress for internal-only access (`className: internal-nginx`, host `gitea.vpn.homebase.internal`).
- Intended access path is VPN-first: user connects through wg-easy/WireGuard, then reaches the internal Gitea hostname.
- Avoid public DNS annotations for Gitea unless your annotation targets a private-only DNS zone.
- Ensure backup for repository integrity.
- Official-chart dependency defaults in shipped overlays disable bundled backends (`gitea.postgresql.enabled=false`, `gitea.postgresql-ha.enabled=false`, `gitea.redis.enabled=false`, `gitea.redis-cluster.enabled=false`) and use external PostgreSQL/Redis settings under `gitea.gitea.config.*`.
- Official-chart Actions are intentionally disabled (`gitea.gitea.actions.enabled=false`) for first-phase Git/PR/wiki workflows; Actions runners are deferred to a later dedicated deployment.
- Admin bootstrap uses official chart fields (`gitea.gitea.admin.username` and `gitea.gitea.admin.existingSecret`) so admin credentials are sourced from Kubernetes Secrets (typically synced from Infisical) instead of plaintext values.
- Sensitive `app.ini` values (DB password, SMTP password, OAuth client secret, internal/security tokens) should be wired with official-chart mechanisms: set env vars from Kubernetes Secrets (`gitea.secretRefs[]` / `gitea.existingSecret`) and list the env names in `gitea.gitea.additionalConfigFromEnvs`; optionally load secret-backed config snippets via `gitea.gitea.additionalConfigSources`.
- Keep non-sensitive defaults (for example `gitea.gitea.config.database.DB_TYPE` and `gitea.gitea.config.service.DISABLE_REGISTRATION`) in versioned values files.
- Size and storage class for Gitea app data should follow the active profile storage conventions (`gitea.persistence.*`). Database/cache persistence is handled by shared backend releases (`sharedPostgresql.*` and `sharedRedis.*`).

### Paperless-ngx

- Multi-volume document pipeline (`data`, `media`, etc.).
- Umbrella toggle is `paperlessNgx.enabled`; the Paperless subchart also has a chart-local `enabled` gate (default `false`) so standalone renders are safe unless explicitly enabled. The umbrella chart sets `paperless-ngx.enabled: true` internally so operators continue using `paperlessNgx.enabled` as the single service toggle.
- Ingress is enabled by default so the UI/API is reachable when the service is enabled.
- Paperless requires PostgreSQL 14+ for the external database backend configuration.
- Canonical Paperless secret wiring uses structured refs rendered with `valueFrom.secretKeyRef`: `paperless-ngx.secretKeySecret.{name,key}` -> `PAPERLESS_SECRET_KEY`, `paperless-ngx.externalDatabase.passwordSecret.{name,key}` -> `PAPERLESS_DBPASS`, `paperless-ngx.redis.urlSecret.{name,key}` (or `paperless-ngx.redis.passwordSecret.{name,key}` when that key stores a full Redis URL) -> `PAPERLESS_REDIS`, and `paperless-ngx.admin.passwordSecret.{name,key}` -> `PAPERLESS_ADMIN_PASSWORD`; `paperless-ngx.redis.url` remains available for direct URL input and `paperless-ngx.redis.prefix` maps to `PAPERLESS_REDIS_PREFIX`.
- Admin bootstrap env wiring is split between values and Secrets: set `paperless-ngx.admin.user` (required) and optional `paperless-ngx.admin.mail` in values, and point `paperless-ngx.admin.passwordSecret.{name,key}` to the synced Kubernetes Secret key that stores the admin password. For Infisical-backed flows, this means syncing the Paperless admin password into a Kubernetes Secret first, then referencing that Secret name/key in chart values.
- The Paperless chart does not introduce a Redis dependency/subchart; operators should point at shared/external Redis.
- Validate storage growth and retention behavior.

### Infisical

- Default-on in-cluster secret-management component based on upstream standalone chart semantics; runtime DB/cache are externalized to shared services.
- Primary knobs are grouped under `infisical.infisical` and `infisical.ingress`; `infisical.postgresql.enabled` and `infisical.redis.enabled` stay `false` for centralized backend mode.
- Uses `infisical.infisical.kubeSecretRef` to point at the runtime/bootstrap secret.
- Runtime secret must include `DB_CONNECTION_URI` and `REDIS_URL` for centralized backend mode (plus `AUTH_SECRET`, `ENCRYPTION_KEY`, `SITE_URL`).
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
- Nextcloud external Postgres/Redis credentials should prefer `nextcloud.externalDatabase.*` and `nextcloud.externalRedis.*` as the canonical path; keep generic secret patterns for compatibility and extra env wiring.
- Paperless required runtime secrets should use `secretKeySecret`, `externalDatabase.passwordSecret`, `redis.urlSecret`/`redis.passwordSecret` (URL key), and `admin.passwordSecret`; keep `existingSecret` and `secretRefs[]` only for optional additive env injection.

Infisical integration is done by syncing provider values into Kubernetes Secret names consumed by each chart (for example `openhands-app-secrets` or a Paperless admin secret referenced by `paperless-ngx.admin.passwordSecret`) and then referencing those names via `existingSecret`, `envFromSecrets`, `secretRefs`, or `secretEnv`.

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
