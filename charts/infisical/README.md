# Infisical chart notes

This chart deploys a durable, VPN-reachable **self-hosted Infisical** instance that connects to external PostgreSQL and Redis services.

## Prerequisites

- Kubernetes **1.23+**
- Helm **3.11.3+**
- `kubectl` access to the target cluster/namespace

## Defaults and architecture choices

- `infisical.service.type: ClusterIP`
- `ingress.enabled: true` with an internal hostname default (`infisical.internal.home.arpa`)
- Infisical image pinned to `infisical/infisical:v0.151.0`
- `infisical.replicaCount: 2`
- In-cluster PostgreSQL and Redis disabled by default (`postgresql.enabled=false`, `redis.enabled=false`)
- Runtime connectivity comes from `DB_CONNECTION_URI` and `REDIS_URL` in `infisical.kubeSecretRef`

This chart is designed to keep Infisical private to VPN/internal users unless you explicitly configure public exposure.

## Required app secret keys

Create (or reuse) the Kubernetes Secret referenced by `infisical.kubeSecretRef` (default: `infisical-secrets`) with at least:

- `AUTH_SECRET`
- `ENCRYPTION_KEY`
- `SITE_URL`

### External DB/Redis note

This repo defaults to **externalized Postgres + Redis**. Provide:

- `DB_CONNECTION_URI`
- `REDIS_URL`

## Recommended SMTP keys

For invitations, password reset, and notifications, include these keys in the same secret:

- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USERNAME`
- `SMTP_PASSWORD`
- `SMTP_FROM_ADDRESS`
- `SMTP_FROM_NAME`

## Ingress and private reachability model

Use an internal/VPN-only hostname in both:

- `ingress.hostName`
- `SITE_URL`

Example: `https://infisical.internal.home.arpa`

Do not expose Infisical publicly by default. If you intentionally expose it externally, enforce TLS and access controls.

## First-admin bootstrap

Two supported approaches:

1. **Preferred: auto-bootstrap**
   - Set `infisical.autoBootstrap.enabled=true`.
   - Create bootstrap credential Secret (keys required):
     - `INFISICAL_ADMIN_EMAIL`
     - `INFISICAL_ADMIN_PASSWORD`
   - Point `infisical.autoBootstrap.credentialSecret.name` at that Secret.
   - The chart bootstraps an admin user + org and writes the bootstrap output token to `infisical.autoBootstrap.secretDestination`.

2. **Manual fallback**
   - Keep `infisical.autoBootstrap.enabled=false` (default).
   - First signup becomes admin.

## Data safety and backup warnings

- 🚨 **Critical:** losing `ENCRYPTION_KEY` means encrypted secret values can never be decrypted, even with a restored PostgreSQL backup.
- PostgreSQL PVC stores Infisical's encrypted secret data and must be treated as critical state.
- Take verified backups of PostgreSQL before upgrades, storage migration, or uninstall.
- Store `ENCRYPTION_KEY` securely **outside the cluster** as part of disaster recovery.

## Install

```bash
kubectl -n infisical create secret generic infisical-secrets \
  --from-literal=AUTH_SECRET='replace-me' \
  --from-literal=ENCRYPTION_KEY='replace-me-with-strong-key' \
  --from-literal=SITE_URL='https://infisical.internal.home.arpa'

helm upgrade --install infisical charts/infisical \
  --namespace infisical \
  --create-namespace
```

## Using Infisical as the secret source for `openclaw` and `wg-easy`

Deploying Infisical alone does **not** sync secrets into Kubernetes Secrets for workloads.
You must also deploy the **Infisical Kubernetes Operator** and create `InfisicalSecret` resources.

### 1) Install the Infisical secrets operator

```bash
helm repo add infisical https://dl.cloudsmith.io/public/infisical/helm-charts/helm/charts/
helm repo update

helm upgrade --install infisical-secrets-operator infisical/secrets-operator \
  --namespace infisical-operator \
  --create-namespace
```

### 2) Configure operator authentication

- Create a Machine Identity in Infisical.
- Grant least-privilege project/environment access.
- Configure operator auth (for example Universal Auth credentials Secret referenced by `InfisicalSecret`).

### 3) Sync app secrets via `InfisicalSecret`

Use one `InfisicalSecret` per workload/env to materialize Kubernetes Secrets consumed by charts.

- `openclaw` synced Kubernetes Secret should include:
  - `OPENCLAW_GATEWAY_TOKEN`
  - `OPENAI_API_KEY`
  - `ANTHROPIC_API_KEY`
- `wg-easy` synced Kubernetes Secret should include:
  - `WG_HOST`
  - `PASSWORD_HASH`

Then set downstream charts to use those synced Kubernetes Secret names (`existingSecret`).
