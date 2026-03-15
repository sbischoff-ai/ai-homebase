# Homelab operations runbook

Use this runbook after initial install to operate `ai-homebase` on a generic Kubernetes/homelab cluster.

## 1) Verify deployment health

Validate chart structure before applying changes:

```bash
./scripts/lint.sh --values-file charts/platform-stack/values-dev.yaml
./scripts/lint.sh --values-file charts/platform-stack/values-dev.yaml --values-file charts/platform-stack/values-k3d.yaml
```

Render manifests to inspect effective values layering:

```bash
./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values-dev.yaml > /tmp/platform-stack-dev.yaml
./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values-dev.yaml --values-file charts/platform-stack/values-k3d.yaml > /tmp/platform-stack-k3d.yaml
```

Run cluster-level health checks after deploy:

```bash
kubectl -n ai-homebase get pods
kubectl -n ai-homebase get ingress
kubectl -n ai-homebase get pvc
kubectl -n ai-homebase describe ingress
```

## 2) Access ingress endpoints and expected hostnames

Default local profile hostnames are:

- `openhands.localtest.me`
- `openclaw.localtest.me` (only if OpenClaw ingress is enabled in your active overlays)

Access checks:

```bash
curl -sS -H 'Host: openhands.localtest.me' http://127.0.0.1/ -o /dev/null -w '%{http_code}\n'
curl -sS -H 'Host: openclaw.localtest.me' http://127.0.0.1/ -o /dev/null -w '%{http_code}\n'
```

For non-local clusters, replace hostnames with your environment overlay values and validate that DNS points at the ingress controller endpoint.

For service-level ingress defaults and toggle behavior, see [services reference](./services.md) and [networking guidance](./networking.md).

## 3) Enable/disable optional services via overlay values

Set service toggles in overlay files, not one-off `--set` flags.

Examples in `charts/platform-stack/values-k3d.yaml`:

- `nextcloud.enabled`
- `gitea.enabled`
- `paperlessNgx.enabled`
- `infisical.enabled`
- `wgEasy.enabled`

Validate toggle rendering explicitly:

```bash
./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values-dev.yaml --disable-service nextcloud --disable-service gitea > /tmp/platform-stack-core-only.yaml
```

Recommended pattern:

1. Keep shared defaults in `charts/platform-stack/values-dev.yaml`.
2. Keep environment/profile differences in `charts/platform-stack/values-k3d.yaml` or another overlay file.
3. Commit overlay file changes so operators can reproduce service posture.

## 4) Re-render and redeploy workflow

When changing values or toggles, run this sequence:

1. Re-lint with the same value files you deploy.
2. Re-render to `/tmp/*.yaml` and inspect changed objects.
3. Redeploy with `helm upgrade --install` using the same value file order.
4. Re-run health and ingress checks.

Example deploy command:

```bash
helm dependency update charts/platform-stack
helm upgrade --install platform-stack charts/platform-stack \
  --namespace ai-homebase \
  --create-namespace \
  -f charts/platform-stack/values-dev.yaml \
  -f charts/platform-stack/values-k3d.yaml
```

## 5) Backup and secret-handling reminders

- Store durable app data on persistent volumes and confirm restore procedures for your storage class. See [storage planning](./storage.md).
- Keep runtime credentials in Kubernetes Secrets and wire them using chart secret contracts (`existingSecret`, `secretRefs`, `secretEnv`, `envFromSecrets`). See [services and secret contracts](./services.md#secret-contract-model-all-services).
- Do not commit plaintext secrets in values files; keep secret values in your secret manager workflow and only commit secret references.
- Before major upgrades, snapshot/backup service data volumes and any backing databases used by optional services.

