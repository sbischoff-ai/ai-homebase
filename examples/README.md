# Examples

All examples in this directory use placeholders only. Replace values like `<your-namespace>`, `<your-release>`, and `<your-kube-context>` before running commands.

## Namespace setup

```bash
kubectl --context <your-kube-context> create namespace <your-namespace>
kubectl --context <your-kube-context> config set-context --current --namespace=<your-namespace>
```

## Dummy secrets for all components

Create image pull and app secrets before first install so optional services can be enabled without secret-related crash loops.

```bash
kubectl --context <your-kube-context> -n <your-namespace> create secret docker-registry acr-pull \
  --docker-server=<your-acr-name>.azurecr.io \
  --docker-username=<dummy-username> \
  --docker-password=<dummy-password> \
  --docker-email=<dummy-email@example.com>

kubectl --context <your-kube-context> -n <your-namespace> create secret generic openclaw-app-secrets \
  --from-literal=OPENCLAW_GATEWAY_TOKEN=<dummy-openclaw-gateway-token>

kubectl --context <your-kube-context> -n <your-namespace> create secret generic openhands-app-secrets \
  --from-literal=LLM_API_KEY=<dummy-llm-api-key> \
  --from-literal=LLM_MODEL=<optional-llm-model> \
  --from-literal=OH_WEB_URL=<optional-openhands-web-url>

kubectl --context <your-kube-context> -n <your-namespace> create secret generic nextcloud-app-secrets \
  --from-literal=NEXTCLOUD_ADMIN_PASSWORD=<dummy-nextcloud-admin-password> \
  --from-literal=POSTGRES_PASSWORD=<dummy-nextcloud-postgres-password> \
  --from-literal=REDIS_HOST_PASSWORD=<dummy-nextcloud-redis-password>

kubectl --context <your-kube-context> -n <your-namespace> create secret generic gitea-app-secrets \
  --from-literal=username=<dummy-gitea-admin-username-not-admin> \
  --from-literal=password=<dummy-gitea-admin-password> \
  --from-literal=GITEA__database__PASSWD=<dummy-gitea-db-password> \
  --from-literal=GITEA__mailer__PASSWD=<dummy-gitea-smtp-password> \
  --from-literal=GITEA__oauth2_client__HOMEBASE__CLIENT_SECRET=<dummy-gitea-oauth-client-secret> \
  --from-literal=GITEA__security__SECRET_KEY=<dummy-gitea-secret-key> \
  --from-literal=GITEA__security__INTERNAL_TOKEN=<dummy-gitea-internal-token>

kubectl --context <your-kube-context> -n <your-namespace> create secret generic paperlessngx-app-secrets \
  --from-literal=PAPERLESS_SECRET_KEY=<dummy-paperless-secret-key>

kubectl --context <your-kube-context> -n <your-namespace> create secret generic infisical-app-secrets \
  --from-literal=INFISICAL_ENCRYPTION_KEY=<dummy-infisical-encryption-key>

kubectl --context <your-kube-context> -n <your-namespace> create secret generic wgeasy-app-secrets \
  --from-literal=WG_HOST=<dummy-vpn-hostname-or-ip> \
  --from-literal=PASSWORD=<dummy-wg-ui-password>
```

For OpenClaw and OpenHands, make sure secret key names match each chart contract:

- OpenClaw reads `secretKeys.gatewayToken` from `charts/openclaw/values.yaml` (default key: `OPENCLAW_GATEWAY_TOKEN`).
- OpenHands secret examples in `charts/openhands/values.yaml` use `secretRefs`/`secretEnv` with `LLM_API_KEY` (plus optional values like `LLM_MODEL` and `OH_WEB_URL` as needed).

For Gitea, use the official chart wiring in overlays: enumerate secret-backed env names in `gitea.gitea.additionalConfigFromEnvs` and optionally reference secret-backed config snippets via `gitea.gitea.additionalConfigSources`, so sensitive `app.ini` values stay out of plaintext YAML.

For Nextcloud, prefer mapping required credentials with explicit value keys (`nextcloud.admin.passwordSecret`, `nextcloud.externalDatabase.passwordSecret`, `nextcloud.externalRedis.passwordSecret`) and keep ingress on a dedicated `cloud.<domain>` host at `/` rather than a shared subpath.

## Install/upgrade with value overlays and service toggles

Use the scripts to combine baseline + override files and explicitly control service toggles.

```bash
./scripts/install-dev.sh \
  --release-name <your-release> \
  --namespace <your-namespace> \
  --kube-context <your-kube-context> \
  --values-file charts/platform-stack/values-dev.yaml \
  --values-file examples/dev.values.override.yaml \
  --values-file examples/profile-content-services.override.yaml \
  --enable-service nextcloud \
  --enable-service gitea \
  --enable-service paperless-ngx

./scripts/install-aks.sh \
  --release-name <your-release> \
  --namespace <your-namespace> \
  --kube-context <your-kube-context> \
  --values-file charts/platform-stack/values-aks.yaml \
  --values-file examples/aks.values.override.yaml \
  --values-file examples/storage-premium.override.yaml \
  --enable-service infisical \
  --enable-service wg-easy \
  --disable-service openhands
```


## k3d local smoke overlay

Use layered values in this order for local k3d smoke tests:

1. `charts/platform-stack/values-dev.yaml`
2. `charts/platform-stack/values-k3d.yaml`
3. `examples/k3d.values.override.yaml` (optional, user-specific)

```bash
./scripts/template.sh \
  --release-name <your-release> \
  --namespace <your-namespace> \
  --kube-context <your-kube-context> \
  --values-file charts/platform-stack/values-dev.yaml \
  --values-file charts/platform-stack/values-k3d.yaml \
  --values-file examples/k3d.values.override.yaml

./scripts/install-dev.sh \
  --release-name <your-release> \
  --namespace <your-namespace> \
  --kube-context <your-kube-context> \
  --values-file charts/platform-stack/values-dev.yaml \
  --values-file charts/platform-stack/values-k3d.yaml \
  --values-file examples/k3d.values.override.yaml
```

## Ingress hostname override example

```yaml
# examples/ingress-hosts.override.yaml
global:
  domain: <your-domain>
  hosts:
    openclaw: openclaw.<your-domain>
    openhands: openhands.<your-domain>
    nextcloud: files.<your-domain>
    gitea: git.<your-domain>
    paperlessNgx: docs.<your-domain>
    infisical: secrets.<your-domain>
    wgEasy: vpn.<your-domain>
```

Pass it with `--values-file examples/ingress-hosts.override.yaml`.

## PVC/storage override examples

```yaml
# examples/storage-premium.override.yaml
global:
  storageClass: managed-csi

openhands:
  persistence:
    enabled: true
    storageClass: managed-csi-premium
    size: 200Gi

nextcloud:
  persistence:
    storageClass: managed-csi-premium
    size: 500Gi

gitea:
  gitea:
    persistence:
      storageClass: managed-csi
      size: 200Gi

paperlessNgx:
  persistence:
    data:
      storageClass: managed-csi-premium
      size: 200Gi
    media:
      storageClass: managed-csi-premium
      size: 1Ti
    consume:
      storageClass: managed-csi
      size: 50Gi
    export:
      storageClass: managed-csi
      size: 50Gi
```

## AKS deployment sequence (core + new services)

Use this order for AKS:

1. Create namespace and baseline secrets.
2. Update placeholders in `examples/aks.values.override.yaml`.
3. Choose profile overlays (for example `examples/profile-content-services.override.yaml` + `examples/storage-premium.override.yaml`).
4. Validate manifests with service toggles.
5. Install/upgrade using AKS script.
6. Verify enabled services only (`openclaw`, `openhands`, `nextcloud`, `gitea`, `paperlessNgx`, `infisical`, `wgEasy`).

```bash
./scripts/template.sh \
  --release-name <your-release> \
  --namespace <your-namespace> \
  --kube-context <your-kube-context> \
  --values-file charts/platform-stack/values-aks.yaml \
  --values-file examples/aks.values.override.yaml \
  --values-file examples/profile-content-services.override.yaml \
  --enable-service infisical \
  --enable-service wg-easy

./scripts/install-aks.sh \
  --release-name <your-release> \
  --namespace <your-namespace> \
  --kube-context <your-kube-context> \
  --values-file charts/platform-stack/values-aks.yaml \
  --values-file examples/aks.values.override.yaml \
  --values-file examples/profile-content-services.override.yaml \
  --enable-service infisical \
  --enable-service wg-easy
```
