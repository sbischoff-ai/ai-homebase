# Infisical chart notes

This chart deploys Infisical with in-cluster PostgreSQL and Redis defaults and supports either automatic or manual first-admin bootstrap.

## Prerequisites

- Kubernetes **1.23+**
- Helm **3.11.3+**
- `kubectl` access to the target cluster/namespace

## Required secret keys

Create (or reuse) the Kubernetes Secret referenced by `infisical.kubeSecretRef` (default: `infisical-secrets`) with at least:

- `AUTH_SECRET`
- `ENCRYPTION_KEY`
- `SITE_URL`

These are required for a healthy in-cluster deployment.

## Recommended SMTP keys

For email-based flows (invites, password reset, notifications), include these keys in the same secret:

- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USERNAME`
- `SMTP_PASSWORD`
- `SMTP_FROM_ADDRESS`
- `SMTP_FROM_NAME`

## Ingress and private reachability model

This chart exposes Infisical behind an Ingress by default (`ingress.enabled: true`) with optional host/TLS configuration via values.

Recommended operational model:

- Use an **internal-only URL** for `SITE_URL` (for example, an internal DNS name).
- Keep ingress scoped to private networking where possible.
- Reach Infisical through your VPN/private network path instead of opening public internet access.

If you do publish an external hostname, ensure TLS and access controls are in place.

## First-admin bootstrap

Two supported approaches:

1. **Preferred: auto-bootstrap**
   - Set `infisical.autoBootstrap.enabled=true`.
   - Provide bootstrap credentials Secret (`INFISICAL_ADMIN_EMAIL`, `INFISICAL_ADMIN_PASSWORD`) via `infisical.autoBootstrap.credentialSecret.name`.
   - On install, the chart runs a post-install bootstrap job and writes root identity credentials to the configured destination Secret.

2. **Manual fallback**
   - Leave `infisical.autoBootstrap.enabled=false` (default).
   - Infisical runs in fallback mode where the first signup becomes admin.

## Data safety and backup warnings

- **Critical key warning:** if you lose `ENCRYPTION_KEY`, encrypted secret payloads cannot be decrypted, even if PostgreSQL is fully restored from backup.
- The PostgreSQL primary PVC stores Infisical's persistent encrypted data and is critical for retention and disaster recovery.
- Always take a verified backup before:
  - chart upgrades,
  - storage changes,
  - or uninstalling the release.

Treat PostgreSQL data + `ENCRYPTION_KEY` as a paired recovery boundary.
