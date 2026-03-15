# k3d local deployment flow

This guide describes the local `k3d` workflow for `platform-stack`, including cluster bootstrap, deploy/smoke checks, ingress host access, and common troubleshooting.

## 0) Prerequisites

Install and verify these tools before running scripts:

- [k3d](https://k3d.io/)
- [Docker](https://docs.docker.com/get-docker/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm 3](https://helm.sh/docs/intro/install/)

Quick verification:

```bash
k3d version
docker version
kubectl version --client
helm version
```

## 1) Bootstrap the local cluster

Create (or reuse) the cluster and install `ingress-nginx`:

```bash
./scripts/k3d-up.sh --cluster-name ai-homebase-dev
```

What this does:

- Creates a k3d cluster and maps host `:80` to cluster load balancer `:80`.
- Optionally maps host `:443` to cluster load balancer `:443` (enabled by default).
- Switches `kubectl` context to `k3d-ai-homebase-dev`.
- Installs/upgrades `ingress-nginx` via Helm with ingress class `nginx`.
- Waits for ingress controller deployment/pods to become ready.

Useful options:

- `--http-port <port>` and `--https-port <port>` if host ports are already in use.
- `--without-https` to skip mapping host HTTPS.

## 2) Deploy and run local smoke checks

Install/upgrade the stack with default local values and run health checks:

```bash
./scripts/test-local-k3d.sh --release-name platform-stack --namespace ai-homebase
```

Default values layers used by the script:

1. `charts/platform-stack/values-dev.yaml`
2. `charts/platform-stack/values-k3d.yaml`

Script behavior summary:

- Runs `helm dependency update charts/platform-stack`.
- Executes `helm upgrade --install ...`.
- Waits for `openclaw` and `openhands` deployments and pods.
- Checks `openclaw` ingress via `Host: openclaw.localtest.me` on `http://127.0.0.1/`.
- Checks `openhands` ingress via `Host: openhands.localtest.me` on `http://127.0.0.1/`.
- Dumps pod diagnostics automatically on failure.

> ⚠️ Important default-profile note: both `values-dev.yaml` and `values-k3d.yaml` keep `openclaw.ingress.enabled=false`.
> That means OpenClaw ingress curl checks are **not** valid for default layering by themselves.
> To make OpenClaw ingress checks pass, add an override file that enables ingress (for example `examples/k3d.values.override.yaml`) and pass it with `--values-file`.

Example command with OpenClaw ingress explicitly enabled:

```bash
./scripts/test-local-k3d.sh \
  --release-name platform-stack \
  --namespace ai-homebase \
  --values-file charts/platform-stack/values-dev.yaml \
  --values-file charts/platform-stack/values-k3d.yaml \
  --values-file examples/k3d.values.override.yaml
```

## 3) Teardown

Delete the local cluster when done:

```bash
./scripts/k3d-down.sh --cluster-name ai-homebase-dev
```

## 4) Local ingress host access (DNS/hosts)

Local ingress host checks use `openclaw.localtest.me` and `openhands.localtest.me` when ingress checks are enabled (OpenClaw requires an explicit override under default profile layering).

### Preferred: `localtest.me` wildcard behavior

`*.localtest.me` resolves to `127.0.0.1` using public DNS, so this works without editing `/etc/hosts` in most environments:

- `openclaw.localtest.me` -> `127.0.0.1`
- `openhands.localtest.me` -> `127.0.0.1`

### Fallback: `/etc/hosts`

If DNS is filtered or unavailable, add host mappings manually:

```text
127.0.0.1 openclaw.localtest.me openhands.localtest.me
```

If you changed values to custom hostnames, map those hosts to `127.0.0.1` as well.

## 5) Common failure modes and fixes

### A) `ImagePullBackOff` on placeholder/private images

Symptoms:

- Pods stuck in `ImagePullBackOff` / `ErrImagePull`.
- `kubectl describe pod` shows auth or repo-not-found errors.

Fixes:

- Replace placeholder image repositories/tags in your values overrides.
- Add pull secrets and reference them via `global.imagePullSecrets` (or service-specific fields).
- Validate image exists and is reachable from local Docker/k3s runtime.

### B) Ingress class mismatch

Symptoms:

- Ingress exists, but no traffic reaches service.
- Ingress controller logs show class mismatch / ignored ingress resources.

Fixes:

- Ensure `ingressClassName` (or annotation) is `nginx` for local k3d usage.
- Confirm ingress controller was installed by `scripts/k3d-up.sh` and is Ready.
- Re-check host header matches ingress host exactly.

### C) Pods Pending due to storage class assumptions

Symptoms:

- PVCs stay `Pending`.
- Events indicate no matching/default `StorageClass`.

Fixes:

- Set `global.storageClass` to a class available in your k3d cluster.
- Override per service where needed.
- If your test scenario allows ephemeral storage, use values that avoid PVC-backed components.

## 6) What success looks like

After bootstrap + deploy with default layering (`values-dev.yaml` + `values-k3d.yaml`), run these checks:

```bash
kubectl get nodes
kubectl -n ingress-nginx get pods
kubectl -n ai-homebase get pods
kubectl -n ai-homebase get ingress
curl -sS -H 'Host: openhands.localtest.me' http://127.0.0.1/ -o /dev/null -w '%{http_code}\n'
kubectl -n ai-homebase get ingress -l app.kubernetes.io/name=openclaw
```

Expected results:

- `kubectl get` commands show `Ready`/`Running` resources with no core-plane crash loops.
- OpenHands curl check returns HTTP `200` (or another known-good success code for your configured app endpoint).
- OpenClaw ingress query returns `No resources found` unless you explicitly enable OpenClaw ingress in an override file.
