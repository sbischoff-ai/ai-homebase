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

This chart exposes Infisical behind an Ingress by default (`infisical.ingress.enabled: true`) with optional host/TLS configuration via values.

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

## End-to-end: Infisical + secrets-operator + app secret sync

This section shows a concrete workflow for using Infisical as the secret source of truth and syncing app-specific values into Kubernetes Secrets that downstream charts already consume.

### 1) Deploy Infisical

Create the backing secret expected by this chart (at least `AUTH_SECRET`, `ENCRYPTION_KEY`, `SITE_URL`; optionally SMTP keys), then install:

```bash
kubectl -n infisical create secret generic infisical-secrets \
  --from-literal=AUTH_SECRET='replace-me' \
  --from-literal=ENCRYPTION_KEY='replace-me-with-strong-key' \
  --from-literal=SITE_URL='https://infisical.internal.example'

helm upgrade --install infisical charts/infisical \
  --namespace infisical \
  --create-namespace
```

### 2) Bootstrap admin/org

Use one of the existing chart-supported flows:

- Auto-bootstrap (`infisical.autoBootstrap.enabled=true`) with bootstrap credential secret (`INFISICAL_ADMIN_EMAIL`, `INFISICAL_ADMIN_PASSWORD`), or
- Manual fallback where first signup becomes admin.

After bootstrap, sign in to Infisical and create/confirm your organization.

### 3) Create projects/environments/secrets

In Infisical, create one project per app (or shared project if you prefer), create environments (for example `dev`, `prod`), and add secret keys.

Recommended keys for this repo:

- `openclaw` project/environment:
  - `OPENCLAW_GATEWAY_TOKEN`
  - `OPENAI_API_KEY` and/or `ANTHROPIC_API_KEY`
- `wg-easy` project/environment:
  - `WG_HOST`
  - `PASSWORD`

### 4) Install Infisical `secrets-operator` chart

Install the operator in-cluster so `InfisicalSecret` custom resources can reconcile to native Kubernetes Secrets.

```bash
helm repo add infisical https://dl.cloudsmith.io/public/infisical/helm-charts/helm/charts/
helm repo update

helm upgrade --install infisical-secrets-operator infisical/secrets-operator \
  --namespace infisical-operator \
  --create-namespace
```

### 5) Configure Machine Identity + Kubernetes Auth

Create a machine identity in Infisical with access to the target project/environment, then configure Kubernetes auth for the operator (service account/JWT flow) as required by the operator version you deploy.

At a high level:

1. Create machine identity + client credentials in Infisical.
2. Grant least-privilege read access to the required secrets.
3. Store the credentials in Kubernetes (in the operator namespace).
4. Create the operator auth custom resource that references those credentials.

### 6) Create `InfisicalSecret` resources to sync to Kubernetes Secrets

Create one `InfisicalSecret` per app/environment and set the output secret names to match what app charts already consume.

Example (`openclaw`): sync to `openclaw-secrets` with keys `OPENCLAW_GATEWAY_TOKEN`, `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`.

```yaml
apiVersion: secrets.infisical.com/v1alpha1
kind: InfisicalSecret
metadata:
  name: openclaw-secrets
  namespace: apps
spec:
  hostAPI: https://infisical.internal.example/api
  resyncInterval: 60
  authentication:
    universalAuthCredentialsRef:
      secretName: infisical-machine-identity
      secretNamespace: infisical-operator
  managedKubeSecretReferences:
    - secretName: openclaw-secrets
      secretNamespace: apps
      creationPolicy: Owner
  secretsScope:
    projectSlug: openclaw
    envSlug: prod
    secretsPath: /
    recursive: true
    includeImports: true
```

Example (`wg-easy`): sync to `wg-easy-secrets` with keys `WG_HOST`, `PASSWORD`.

```yaml
apiVersion: secrets.infisical.com/v1alpha1
kind: InfisicalSecret
metadata:
  name: wg-easy-secrets
  namespace: apps
spec:
  hostAPI: https://infisical.internal.example/api
  resyncInterval: 60
  authentication:
    universalAuthCredentialsRef:
      secretName: infisical-machine-identity
      secretNamespace: infisical-operator
  managedKubeSecretReferences:
    - secretName: wg-easy-secrets
      secretNamespace: apps
      creationPolicy: Owner
  secretsScope:
    projectSlug: wg-easy
    envSlug: prod
    secretsPath: /
    recursive: true
    includeImports: true
```

Then wire charts to these synced secret names.

`openclaw` values:

```yaml
existingSecret: openclaw-secrets
secretKeys:
  gatewayToken: OPENCLAW_GATEWAY_TOKEN
  openaiApiKey: OPENAI_API_KEY
  anthropicApiKey: ANTHROPIC_API_KEY
```

`wg-easy` values:

```yaml
existingSecret: wg-easy-secrets
```

`openclaw` and `wg-easy` already read environment variables from Kubernetes Secrets via their existing `existingSecret` and secret-key mappings. Using `InfisicalSecret` just automates keeping those Kubernetes Secrets up to date.
