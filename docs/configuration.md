# Configuration and values layering

This project uses Helm values layering to keep environment configuration explicit and reproducible.

## Values hierarchy (lowest to highest precedence)

1. `charts/platform-stack/values.yaml`
2. Profile overlay (`values-dev.yaml`, `values-k3d.yaml`, `values-aks.yaml`, `values-prod.yaml`)
3. Environment/team overlay file(s) (`-f values-<profile>.<env>.yaml`)
4. CLI overrides (`--set`, `--set-string`, `--set-file`)

Prefer files over `--set` for anything long-lived or shared.

## Layering model

### Layer A: base chart defaults

Use `values.yaml` for safe, reusable defaults that should apply broadly.

### Layer B: profile overlays

Use profile files to encode environment class behavior:

- `values-dev.yaml`: low-cost local/dev defaults.
- `values-k3d.yaml`: k3d local-smoke overlay (loaded after `values-dev.yaml`).
- `values-aks.yaml`: AKS assumptions and cloud integration placeholders.
- `values-prod.yaml`: production-shaped resource/availability posture.
- `values-homelab-public-nextcloud.yaml`: homelab posture with public Nextcloud (`cloud.<domain>`) and VPN-only ingress hostnames for internal services.

### Layer C: environment overlays

Create an overlay per real environment (for example `values-aks.prod-eu.yaml` or `charts/platform-stack/values-homelab-public-nextcloud.yaml`) for:

- Real domains/hosts.
- Actual secret references.
- Service toggles for that environment.
- Storage class and sizing overrides.

### Layer D: runtime one-offs

Use CLI overrides only for temporary experiments, never as the only source of critical production config.

## Values schema validation

Helm now validates values against JSON schemas when running `helm lint`, `helm template`, and `helm install/upgrade` for charts that include `values.schema.json`.

Current schema coverage:

- `charts/platform-stack/values.schema.json` validates top-level structure for `global`, `openclaw`, `openhands`, and optional-service toggles (`nextcloud.enabled`, `gitea.enabled`, `paperlessNgx.enabled`, `infisical.enabled`, `wgEasy.enabled`).
- `charts/openclaw/values.schema.json` validates OpenClaw-specific high-risk fields such as ingress hosts, service type, persistence storage class, and secret reference mappings.
- `charts/openhands/values.schema.json` validates OpenHands-specific high-risk fields such as ingress host name, service type, persistence storage class, and secret reference mappings.

### Extending schema coverage safely

When adding or changing values keys, update both `values.yaml` and `values.schema.json` in the same chart so CI catches invalid configurations early.

Recommended schema conventions:

- Add `description` to operator-sensitive fields (hosts, storage class, service exposure, secret references).
- Use `enum` where Kubernetes expects constrained values (for example service `type`).
- Keep `additionalProperties: true` on parent objects unless strict lock-down is intentional, so overlays can evolve incrementally.
- Add `required` only for fields that must always exist to avoid breaking layered profiles unintentionally.

## Global vs service-specific values

Use `global.*` for shared conventions:

- Domain and default host naming patterns.
- Image pull secrets.
- Shared labels/annotations.
- Optional shared storage class default.

Use service-specific blocks when behavior must diverge:

- `openclaw.*` and `openhands.*` for core-plane differences.
- Optional service blocks for app-specific scaling/storage/ingress.
- Gitea official-chart dependency knobs are configured under `gitea.gitea.*` in platform overlays (for example `gitea.gitea.config.*`, `gitea.gitea.admin.*`, `gitea.gitea.actions.*`, `gitea.gitea.additionalConfigFromEnvs`, `gitea.gitea.additionalConfigSources`, `gitea.gitea.postgresql.*`, `gitea.gitea.postgresql-ha.*`, `gitea.gitea.redis.*`, and `gitea.gitea.redis-cluster.*`; bundled backends remain disabled by default in shipped profiles).
- Service-level secret references and env contracts.
- OpenClaw runtime configuration should be expressed via structured `openclaw.*` values (rendered to `openclaw.json`) rather than generic key/value config blobs.

## OpenHands persistence key migration

Canonical schema for OpenHands storage is `openhands.persistence.*`. All shipped platform profiles (`charts/platform-stack/values-*.yaml`) and storage examples now use `persistence.*` directly.

`openhands.workspace.*` remains a temporary compatibility alias that maps to the same behavior during the migration window.

Deprecation timeline: compatibility support for `openhands.workspace.*` is planned for removal in the first chart release after **2026-01-31**. Update any custom overlays to `openhands.persistence.*` before that release.

## Toggle strategy for service composition

Canonical baseline defaults come from `charts/platform-stack/values.yaml`: `openclaw.enabled`, `openhands.enabled`, `nextcloud.enabled`, `infisical.enabled`, and `wgEasy.enabled` are `true`, while `gitea.enabled` and `paperlessNgx.enabled` are `false`.

Treat all service toggles as explicit decisions in each environment overlay:

Profile note: Gitea values in shipped `charts/platform-stack/values*.yaml` are intentionally internal-only (`service.type: ClusterIP`, `ingress.className: internal-nginx`, host `gitea.vpn.homebase.internal`). Keep DNS for that host private (for example reachable only through wg-easy/WireGuard).


- `nextcloud.enabled`
- `gitea.enabled`
- `paperlessNgx.enabled`

For Paperless specifically, baseline and shipped overlays keep `paperlessNgx.ingress.enabled: false` by default (VPN/internal-first posture); enable ingress only in overlays where internal ingress routing is intentionally required.

For Paperless specifically, the umbrella defaults also set `paperless-ngx.enabled: true` as a compatibility bridge so `paperlessNgx.enabled` remains the operator-facing toggle while the subchart can stay standalone-safe by default.

- `infisical.enabled`
- `wgEasy.enabled`

Do not rely on ad-hoc CLI toggles for persistent environments.

## Secret layering guidance

Current supported runtime contracts:

- `existingSecret`
- `secretKeys.gatewayToken` (OpenClaw gateway token key mapping)
- optional OpenClaw provider/search mappings under `secretKeys.*ApiKey`
- `envFromSecrets[]`
- `secretRefs[]`
- `secretEnv[]`
- Nextcloud canonical external backend keys: `nextcloud.externalDatabase.*` and `nextcloud.externalRedis.*` (mapped to explicit `POSTGRES_*` and `REDIS_*` env vars in the Nextcloud StatefulSet)
- Paperless admin/bootstrap keys: required `paperless-ngx.admin.user`, optional `paperless-ngx.admin.mail`, and required secret ref `paperless-ngx.admin.passwordSecret.{name,key}` -> `PAPERLESS_ADMIN_PASSWORD`.
- Paperless canonical secret refs: `paperless-ngx.secretKeySecret.{name,key}` -> `PAPERLESS_SECRET_KEY`, `paperless-ngx.externalDatabase.passwordSecret.{name,key}` -> `PAPERLESS_DBPASS`, `paperless-ngx.redis.urlSecret.{name,key}` (or `paperless-ngx.redis.passwordSecret.{name,key}` when storing a composed Redis URL) -> `PAPERLESS_REDIS`, and `paperless-ngx.admin.passwordSecret.{name,key}` -> `PAPERLESS_ADMIN_PASSWORD`; `paperless-ngx.redis.url` remains supported for direct non-secret URL input and `paperless-ngx.redis.prefix` maps to `PAPERLESS_REDIS_PREFIX`.
- Paperless app config keys: `paperless-ngx.appConfig.url` -> `PAPERLESS_URL`, `paperless-ngx.appConfig.allowedHosts` -> `PAPERLESS_ALLOWED_HOSTS`, `paperless-ngx.appConfig.csrfTrustedOrigins` -> `PAPERLESS_CSRF_TRUSTED_ORIGINS`, `paperless-ngx.appConfig.corsAllowedHosts` -> `PAPERLESS_CORS_ALLOWED_HOSTS`, `paperless-ngx.appConfig.timeZone` -> `PAPERLESS_TIME_ZONE` (default `Europe/Berlin`), and `paperless-ngx.appConfig.ocrLanguage` -> `PAPERLESS_OCR_LANGUAGE` (default `deu+eng`).
- Paperless network isolation controls: `paperless-ngx.networkPolicy.*` (ingress controller selectors, optional wg-easy namespace selectors, and DNS/PostgreSQL/Redis egress selectors).
- Nextcloud bootstrap/runtime keys: `nextcloud.admin.user`, required secret refs `nextcloud.admin.passwordSecret.{name,key}` + `nextcloud.externalDatabase.passwordSecret.{name,key}` (+ `nextcloud.externalRedis.passwordSecret.{name,key}` when Redis auth is enabled), `nextcloud.trustedDomains` (list or delimited string), `nextcloud.overwriteProtocol`, `nextcloud.php.memoryLimit`, `nextcloud.php.uploadLimit`, `nextcloud.initHtaccess`, `nextcloud.smtp.{host,port,user,passwordSecret.{name,key},fromAddress,domain}`, `nextcloud.initialApps[]`, `nextcloud.podSecurityContext`, and `nextcloud.containerSecurityContext`
- Nextcloud network isolation controls: `nextcloud.networkPolicy.*` (ingress controller selector, DNS/PostgreSQL/Redis egress, and optional SMTP egress selectors).

Recommended layering:

- Keep provider/bootstrap details out of chart profile files.
- For Nextcloud external backends, set connection metadata with `nextcloud.externalDatabase.*`/`nextcloud.externalRedis.*` and reference password keys via `passwordSecret.{name,key}`.
- For Nextcloud trusted hosts, set `nextcloud.trustedDomains` as either a YAML list or a delimited string; ensure `cloud.<domain>` is always present.
- Keep Nextcloud on a dedicated hostname (`cloud.<domain>`) routed at `/`; avoid subpath exposure to preserve Android/WebDAV/public-link compatibility.
- Set `nextcloud.ingress.hosts[]`, `nextcloud.trustedDomains`, and TLS/DNS records to the same canonical public host to avoid redirect/share-link drift.
- Put only secret **references** in environment overlays (for Gitea sensitive `app.ini` keys, prefer upstream-chart secret/env wiring with `gitea.gitea.additionalConfigFromEnvs` and optionally `gitea.gitea.additionalConfigSources`).
- Generate target Kubernetes Secrets via External Secrets or controlled secret bootstrap processes.

## Example deployment command pattern

```bash
helm upgrade --install platform-stack charts/platform-stack \
  -n <namespace> \
  -f charts/platform-stack/values-<profile>.yaml \
  -f values-<profile>.<env>.yaml
```

## Intentional placeholders and production gaps

The configuration model leaves several items intentionally unresolved:

- Queue provider endpoints/credentials.
- External secret store IDs and key mappings.
- Final observability sinks and retention policy.
- Hardened network policy definitions.

Track these as mandatory production-readiness tasks, not optional cleanup.
