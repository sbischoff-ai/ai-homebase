# Nextcloud chart

This chart deploys Nextcloud as a single primary web workload plus a dedicated cron worker, with data persisted at `/var/www/html`.

## Architecture

- **Application runtime:** standard `nextcloud:<tag>-apache` container image in a `StatefulSet`.
- **Database/cache model:** external PostgreSQL and external Redis are expected via `externalDatabase.*` and `externalRedis.*` values.
- **Background jobs:** a dedicated `CronJob` (`nextcloud.cron.*`) runs `php -f /var/www/html/cron.php` on a schedule and mounts the same data path.

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

Use a **dedicated hostname** such as `cloud.<domain>` and route Nextcloud at `/`.

- Supported/recommended: `https://cloud.example.com/`
- Not recommended: `https://example.com/cloud` (subpath)

Set `trustedDomains` to include the exact public hostname (for example `cloud.example.com`) and keep `overwriteProtocol: https` for TLS-terminated ingress.

## Android and public-link compatibility notes

- The Nextcloud Android app and public share links are most reliable with a dedicated host rooted at `/`.
- Subpath publishing often breaks WebDAV discovery, redirect handling, and generated public URLs.
- Keep the canonical host stable across upgrades/migrations and ensure the same host appears in:
  - ingress `hosts[]`
  - `trustedDomains`
  - DNS and TLS certificates

## Upgrade policy

Upgrade **one Nextcloud major version at a time**.

Before each major step:

1. Back up the external PostgreSQL database.
2. Snapshot/back up the Nextcloud data PVC (`/var/www/html`).
3. Verify restore procedures (database + PVC) in a non-production environment.

After upgrade, validate app health, background jobs, and external integrations before proceeding to the next major.
