# Nextcloud chart

This chart deploys Nextcloud as a single primary web workload plus a dedicated cron worker, with data persisted at `/var/www/html`.

## Architecture

- **Application runtime:** standard `nextcloud:<tag>-apache` container image in a `StatefulSet`.
- **Database/cache model:** external PostgreSQL and external Redis are expected via `externalDatabase.*` and `externalRedis.*` values.
- **Background jobs:** a dedicated `CronJob` (`nextcloud.cron.*`) runs `php -f /var/www/html/cron.php` on a schedule and mounts the same data path.
- **System settings convergence:** `skeletonDirectory` is reconciled through both a first-install entrypoint hook and later `occ` reconciliation so new users can start without the default example-file skeleton.
- **Bootstrap apps:** optional `bootstrapApps[]` renders a post-install/post-upgrade Job that waits for Nextcloud readiness, then converges the requested app set through `occ app:install` and `occ app:enable`.
- **Bootstrap users:** optional `bootstrapUsers[]` renders a post-install/post-upgrade Job that waits for Nextcloud readiness, then creates listed local users if missing, reconciles their display names, and resets their passwords through `occ`.
- **Bootstrap project content:** optional `bootstrapProjectContent[]` renders a post-install/post-upgrade Job that creates managed project content under `/Projects/<slug>/` and `/Notes/<slug>/` for a target user, then rescans those paths into Nextcloud.
- **Restart safety:** startup checks never delete persisted Nextcloud state based on `occ status`; restart failures remain inspectable instead of mutating the PVC-backed runtime.

## Required secrets

The chart supports compatibility patterns (`existingSecret`, `secretRefs[]`), but for deterministic deployments you should provide explicit secret references for required credentials:

1. **Admin bootstrap password**
   - Value path: `admin.passwordSecret.{name,key}`
   - Env var rendered: `NEXTCLOUD_ADMIN_PASSWORD`
2. **PostgreSQL password**
   - Value path: `externalDatabase.passwordSecret.{name,key}`
   - Env var rendered: `POSTGRES_PASSWORD`
3. **Redis password** (when Redis auth is enabled)
   - Value path: `externalRedis.passwordSecret.{name,key}`
   - Env var rendered: `REDIS_HOST_PASSWORD`

Optional SMTP auth can be provided via `smtp.passwordSecret.{name,key}` (rendered as `SMTP_PASSWORD`).

### Example secret keys

If you keep a single secret for Nextcloud, these key names are recommended and align with rendered env vars:

- `NEXTCLOUD_ADMIN_PASSWORD`
- `POSTGRES_PASSWORD`
- `REDIS_HOST_PASSWORD`
- `SMTP_PASSWORD` (optional)

## Ingress requirement: dedicated hostname

Use dedicated hostnames and route Nextcloud at `/`.

- Private/internal example: `https://nextcloud.localtest.me/`
- Public example: `https://nextcloud.example.com/`
- Not recommended: `https://example.com/cloud` (subpath)

The chart renders two separate ingress resources that point to the same Service:

- `ingress.private.*` for the private/internal hostname and certificate
- `ingress.public.*` for the public hostname and certificate

Set `trustedDomains` to include every hostname that may reach the instance. Keep `overwriteProtocol: https` for TLS-terminated ingress, prefer `TRUSTED_PROXIES` over fixed overwrite parameters, and only set `overwriteHost` if automatic forwarded-host detection fails behind your proxy.

## Android and public-link compatibility notes

- The Nextcloud Android app and public share links are most reliable with a dedicated host rooted at `/`.
- Subpath publishing often breaks WebDAV discovery, redirect handling, and generated public URLs.
- Keep the canonical host stable across upgrades/migrations and ensure the same host appears in:
  - `ingress.private.host` and, when enabled, `ingress.public.host`
  - `trustedDomains`
  - DNS and TLS certificates

## Upgrade policy

Upgrade **one Nextcloud major version at a time**.

Before each major step:

1. Back up the external PostgreSQL database.
2. Snapshot/back up the Nextcloud data PVC (`/var/www/html`).
3. Verify restore procedures (database + PVC) in a non-production environment.

After upgrade, validate app health, background jobs, and external integrations before proceeding to the next major.

## Failure handling

The chart treats `php occ status` as a readiness signal only.

If a restart finds broken or incomplete persisted state:

- the pod may stay unready or fail;
- bootstrap Jobs keep waiting for a healthy installed instance;
- operator inspection or restore is required instead of chart-managed deletion of `config/config.php`.

## App bootstrap model

Use `bootstrapApps[]` when you want Helm bootstrap and later reruns to keep a specific app set present. The standard stack uses that path for:

- `notes`
- `tables`
- `calendar`
- `tasks`

`initialApps[]` remains available for the image entrypoint hook, but it only participates in first-time container bootstrap and is not the standard convergent path in this repo.

## Project content bootstrap model

Use `bootstrapProjectContent[]` when you want Helm bootstrap and later reruns to keep specific project documentation present for a Nextcloud user.

Each entry defines:

- `slug`: project identifier, used under both `/Projects/<slug>/` and `/Notes/<slug>/`
- `ownerUsername`: Nextcloud user that owns the seeded content
- `projectsFiles[]`: durable curated files written into `/Projects/<slug>/`
- `notes[]`: temporary working notes written into `/Notes/<slug>/`

The chart still supports that inline form directly. The umbrella `platform-stack` chart also supports file-backed project content by selecting `projectsFilesDir` and `notesFilesDir`, then rendering the bootstrap ConfigMap/Job from chart-owned files in `charts/platform-stack/files/`.

This repo treats those locations differently:

- `/Projects/` is durable structured storage for long-lived docs and outputs
- `/Notes/` is working memory and planning scratch space

The bootstrap job writes managed markdown files into the user's Nextcloud storage and rescans the affected paths with `occ files:scan` so the content appears in Nextcloud without requiring external WebDAV or Notes API calls during chart bootstrap.
