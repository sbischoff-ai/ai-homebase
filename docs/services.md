# Service secret contracts

This document standardizes how each service chart consumes secrets now and how to map future ExternalSecret resources.

## Shared secret contract pattern

All service charts support:

- `existingSecret`: optional, imports all keys from one pre-created Kubernetes Secret (`envFrom.secretRef`).
- `secretRefs[]`: optional, fine-grained key mapping to env vars (`name`, `key`, `envVar`).

Naming convention:

- Secret names: `kebab-case` (example: `gitea-app-secrets`).
- Secret keys: `UPPER_SNAKE_CASE` (example: `GITEA_ADMIN_PASSWORD`).
- `secretRefs[].envVar` should generally match the referenced key.

## Current pattern: pre-created Kubernetes Secrets

For each service, create the Secret first (manually, GitOps-sealed flow, or another controller), then set values like:

```yaml
existingSecret: <service>-app-secrets
secretRefs:
  - name: <service>-app-secrets
    key: <SERVICE_SPECIFIC_KEY>
    envVar: <SERVICE_SPECIFIC_KEY>
```

## Target pattern: External Secrets + Infisical provider/operator

Target architecture:

1. External Secrets Operator reconciles `ExternalSecret` resources.
2. Provider backend (including Infisical provider/operator flow) sources real credentials.
3. ESO writes Kubernetes Secrets (target names below).
4. Service chart values reference those target Secrets via `existingSecret`/`secretRefs`.

---

## OpenClaw

Target Secret: `openclaw-app-secrets`

```yaml
openclaw:
  existingSecret: openclaw-app-secrets
  secretRefs:
    - name: openclaw-app-secrets
      key: OPENCLAW_API_TOKEN
      envVar: OPENCLAW_API_TOKEN
```

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: openclaw-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: platform-secrets-store
    kind: ClusterSecretStore
  target:
    name: openclaw-app-secrets
  data:
    - secretKey: OPENCLAW_API_TOKEN
      remoteRef:
        key: /platform/openclaw/api-token
```

## OpenHands

Target Secret: `openhands-app-secrets`

```yaml
openhands:
  existingSecret: openhands-app-secrets
  secretRefs:
    - name: openhands-app-secrets
      key: OPENHANDS_API_TOKEN
      envVar: OPENHANDS_API_TOKEN
```

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: openhands-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: platform-secrets-store
    kind: ClusterSecretStore
  target:
    name: openhands-app-secrets
  data:
    - secretKey: OPENHANDS_API_TOKEN
      remoteRef:
        key: /platform/openhands/api-token
```

## Nextcloud

Target Secret: `nextcloud-app-secrets`

```yaml
nextcloud:
  existingSecret: nextcloud-app-secrets
  secretRefs:
    - name: nextcloud-app-secrets
      key: NEXTCLOUD_ADMIN_PASSWORD
      envVar: NEXTCLOUD_ADMIN_PASSWORD
```

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: nextcloud-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: platform-secrets-store
    kind: ClusterSecretStore
  target:
    name: nextcloud-app-secrets
  data:
    - secretKey: NEXTCLOUD_ADMIN_PASSWORD
      remoteRef:
        key: /platform/nextcloud/admin-password
```

## Gitea

Target Secret: `gitea-app-secrets`

```yaml
gitea:
  existingSecret: gitea-app-secrets
  secretRefs:
    - name: gitea-app-secrets
      key: GITEA_ADMIN_PASSWORD
      envVar: GITEA_ADMIN_PASSWORD
```

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: gitea-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: platform-secrets-store
    kind: ClusterSecretStore
  target:
    name: gitea-app-secrets
  data:
    - secretKey: GITEA_ADMIN_PASSWORD
      remoteRef:
        key: /platform/gitea/admin-password
```

## Paperless-ngx

Target Secret: `paperlessngx-app-secrets`

```yaml
paperlessNgx:
  existingSecret: paperlessngx-app-secrets
  secretRefs:
    - name: paperlessngx-app-secrets
      key: PAPERLESS_SECRET_KEY
      envVar: PAPERLESS_SECRET_KEY
```

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: paperlessngx-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: platform-secrets-store
    kind: ClusterSecretStore
  target:
    name: paperlessngx-app-secrets
  data:
    - secretKey: PAPERLESS_SECRET_KEY
      remoteRef:
        key: /platform/paperlessngx/secret-key
```

## Infisical

Target Secret: `infisical-app-secrets`

```yaml
infisical:
  existingSecret: infisical-app-secrets
  secretRefs:
    - name: infisical-app-secrets
      key: INFISICAL_ENCRYPTION_KEY
      envVar: INFISICAL_ENCRYPTION_KEY
```

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: infisical-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: platform-secrets-store
    kind: ClusterSecretStore
  target:
    name: infisical-app-secrets
  data:
    - secretKey: INFISICAL_ENCRYPTION_KEY
      remoteRef:
        key: /platform/infisical/encryption-key
```

## wg-easy

Target Secret: `wgeasy-app-secrets`

```yaml
wgEasy:
  existingSecret: wgeasy-app-secrets
  secretRefs:
    - name: wgeasy-app-secrets
      key: WG_EASY_PASSWORD_HASH
      envVar: WG_EASY_PASSWORD_HASH
```

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: wgeasy-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: platform-secrets-store
    kind: ClusterSecretStore
  target:
    name: wgeasy-app-secrets
  data:
    - secretKey: WG_EASY_PASSWORD_HASH
      remoteRef:
        key: /platform/wgeasy/password-hash
```
