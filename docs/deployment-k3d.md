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

## 1) Recommended: one-command local bootstrap (cluster + secrets + deploy)

Run the full local setup flow:

```bash
export OPENAI_API_KEY="<your-openai-api-key>"
./scripts/k3d-local-bootstrap.sh --cluster-name ai-homebase-dev
```

Use `--verbose` (or `BOOTSTRAP_VERBOSE=1`) when you want full command output streamed live instead of the default concise progress mode.

This workflow is user-focused and script-guided:

- Creates or reuses the k3d cluster.
- Writes a dedicated kubeconfig (`~/.kube/k3d-<cluster>.yaml`) so local setup is independent from any other project kubeconfigs.
- Installs ingress-nginx.
- Generates required local bootstrap secrets (shared Postgres/Redis auth, OpenClaw gateway token, wg-easy keys, Infisical app secret).
- Deploys `platform-stack` with `values-dev.yaml + values-k3d.yaml`.
- Runs local smoke checks.

## 2) Manual step-by-step flow (advanced/debug)

### 2.1 Bootstrap the local cluster

Create (or reuse) the cluster and install `ingress-nginx`:

```bash
./scripts/k3d-up.sh --cluster-name ai-homebase-dev
```

What this does:

- Creates a k3d cluster and maps host `:80` to cluster load balancer `:80`.
- Optionally maps host `:443` to cluster load balancer `:443` (enabled by default).
- Switches `kubectl` context to `k3d-ai-homebase-dev`.
- Runs a short warm-up (waits for node readiness and, when present, metrics APIService availability) to reduce transient API discovery errors during first install.
- Installs/upgrades `ingress-nginx` via Helm with ingress class `nginx`.
- Waits for ingress controller deployment/pods to become ready.

Useful options:

- `--http-port <port>` and `--https-port <port>` if host ports are already in use.
- `--without-https` to skip mapping host HTTPS.

`k3d-up.sh` writes and uses a dedicated kubeconfig by default (`~/.kube/k3d-<cluster>.yaml`), so this flow works even when your shell has a multi-entry `KUBECONFIG` for other projects.

For WireGuard local testing, `k3d-up.sh` maps host ports `51820/udp` and `51821/tcp` to the k3d server node and mounts host `/lib/modules` into all k3d nodes (`/lib/modules:/lib/modules@all`) so wg-easy can load kernel module metadata needed by `wg-quick`.

### 2.2 Generate minimal bootstrap secrets

```bash
export OPENAI_API_KEY="<your-openai-api-key>"
./scripts/k3d-bootstrap-secrets.sh \
  --namespace ai-homebase \
  --release-name platform-stack \
  --kubeconfig ~/.kube/k3d-ai-homebase-dev.yaml
```

The script prints the generated wg-easy UI password at the end and fails early with a helpful message when `OPENAI_API_KEY` is not set.

All bootstrap scripts now write full command logs to `/tmp/ai-homebase-bootstrap-<timestamp>.log` and print that path in both success and failure summaries.

### 2.3 Deploy and run local smoke checks

Install/upgrade the stack with default local values and run health checks:

```bash
./scripts/test-local-k3d.sh \
  --release-name platform-stack \
  --namespace ai-homebase \
  --kubeconfig ~/.kube/k3d-ai-homebase-dev.yaml
```

If you only want to run the install/upgrade step (without smoke checks), use:

```bash
./scripts/install.sh --profile dev \
  --values-file charts/platform-stack/values-dev.yaml \
  --values-file charts/platform-stack/values-k3d.yaml
```

Default values layers used by the script:

1. `charts/platform-stack/values-dev.yaml`
2. `charts/platform-stack/values-k3d.yaml`

Script behavior summary:

- Runs `helm dependency update charts/platform-stack`.
- Executes `helm upgrade --install ...`.
- Waits for `openclaw` and `openhands` deployments and pods.
- Detects effective `openclaw.ingress.enabled` from the installed release values.
- Checks `openclaw` ingress via `Host: openclaw.localtest.me` on `http://127.0.0.1/` **only when** effective `openclaw.ingress.enabled=true`; otherwise logs an info message and skips this probe.
- Checks `openhands` ingress via `Host: openhands.localtest.me` on `http://127.0.0.1/`.
- On failure, prints failed command, short log excerpt, top-level Kubernetes status, and targeted next-step commands; full `kubectl describe pod/...` output remains available in `--verbose` mode.

> Default profile posture: `values-dev.yaml` + `values-k3d.yaml` keep `openclaw.ingress.enabled=false`.
> This is intentional: public ingress exposure for OpenClaw (and other internal services) is a local testing/debug edge case.
> Normal access posture is VPN-first via wg-easy, with public exposure typically limited to explicitly allowed endpoints (for example Nextcloud when intentionally configured).

Example command with OpenClaw ingress explicitly enabled:

```bash
./scripts/test-local-k3d.sh \
  --release-name platform-stack \
  --namespace ai-homebase \
  --values-file charts/platform-stack/values-dev.yaml \
  --values-file charts/platform-stack/values-k3d.yaml \
  --values-file examples/k3d.values.override.yaml
```

## 3) Connect and use services (user flow)

### 3.1 Access service UIs from your browser

- **wg-easy UI:** `http://wg.localtest.me`
- **OpenHands UI:** `http://openhands.localtest.me`
- **Infisical UI:** `http://infisical.localtest.me`

`openclaw` remains service-only by default in shipped local layering (`openclaw.ingress.enabled=false`).
That is intentional for VPN/internal posture. To expose OpenClaw via local ingress for browser access,
layer `examples/k3d.values.override.yaml` (or your own override) with `openclaw.ingress.enabled=true`.

### 3.2 Connect WireGuard VPN via wg-easy

1. Open `http://wg.localtest.me`.
2. Log in with the generated password printed by `scripts/k3d-bootstrap-secrets.sh` (or `scripts/k3d-local-bootstrap.sh`).
3. Create a client profile in wg-easy and download/show the QR code.
4. Import the profile into your WireGuard client.
5. Connect and verify tunnel status in wg-easy.

### 3.3 Verify service reachability after VPN connection

```bash
kubectl --kubeconfig ~/.kube/k3d-ai-homebase-dev.yaml -n ai-homebase get pods
kubectl --kubeconfig ~/.kube/k3d-ai-homebase-dev.yaml -n ai-homebase get ingress
curl -sS -H 'Host: wg.localtest.me' http://127.0.0.1/ -o /dev/null -w '%{http_code}\n'
curl -sS -H 'Host: openhands.localtest.me' http://127.0.0.1/ -o /dev/null -w '%{http_code}\n'
curl -sS -H 'Host: infisical.localtest.me' http://127.0.0.1/ -o /dev/null -w '%{http_code}\n'
```

## 4) Teardown

Delete the local cluster when done:

```bash
./scripts/k3d-down.sh --cluster-name ai-homebase-dev
```

## 5) Local ingress host access (DNS/hosts)

Local ingress host checks always include `openhands.localtest.me`; `openclaw.localtest.me` is only used when effective `openclaw.ingress.enabled=true`.

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

## 6) Common failure modes and fixes

### A) Multiple kubeconfigs and missing context after cluster create

Symptoms:

- `k3d` reports cluster creation succeeded, but `kubectl config use-context` fails.
- Errors like `no context exists with the name: k3d-<cluster>` or connection attempts to `localhost:8080`.

Why this happens:

- Your environment uses a multi-entry `KUBECONFIG` for several projects.

Fix:

- Use the dedicated kubeconfig written by `scripts/k3d-up.sh` (or pass `--kubeconfig <path>` explicitly).
- Run all follow-up commands with `--kubeconfig <path>` or `export KUBECONFIG=<path>` for this session.

### B) First-run `k3d-up.sh` probe reports cluster not found

Symptoms:

- During first bootstrap of a new cluster name, `k3d-up.sh` logs an info message: `Cluster not found; creating new cluster ...`.

Why this happens:

- `scripts/k3d-up.sh` probes `k3d kubeconfig get <cluster>` to decide whether to reuse or create a cluster.
- On the very first run for a cluster name, "not found" is expected and triggers cluster creation.

Fix:

- No action needed for first run; this is normal behavior.
- If the probe fails for another reason, `k3d-up.sh` still prints the real error and exits so unexpected failures are surfaced.

### C) `ImagePullBackOff` on placeholder/private images

Symptoms:

- Pods stuck in `ImagePullBackOff` / `ErrImagePull`.
- `kubectl describe pod` shows auth or repo-not-found errors.

Fixes:

- Replace placeholder image repositories/tags in your values overrides.
- Add pull secrets and reference them via `global.imagePullSecrets` (or service-specific fields).
- Validate image exists and is reachable from local Docker/k3s runtime.

### D) Ingress class mismatch

Symptoms:

- Ingress exists, but no traffic reaches service.
- Ingress controller logs show class mismatch / ignored ingress resources.

Fixes:

- Ensure `openhands.ingress.ingressClassName` is `nginx` for local k3d usage (annotation fallback is not used by the OpenHands chart contract).
- Confirm ingress controller was installed by `scripts/k3d-up.sh` and is Ready.
- Re-check host header matches ingress host exactly.

### E) Pods Pending due to storage class assumptions

Symptoms:

- PVCs stay `Pending`.
- Events indicate no matching/default `StorageClass`.

Fixes:

- Set `global.storageClass` to a class available in your k3d cluster.
- Override per service where needed.
- If your test scenario allows ephemeral storage, use values that avoid PVC-backed components.

## 7) What success looks like

- If `openclaw` enters `CrashLoopBackOff` with `connect: connection refused` on `/startupz`, check `kubectl -n ai-homebase logs deploy/platform-stack-openclaw --previous` and validate resource sizing from the active overlay. The shipped k3d profile now uses significantly larger OpenClaw resources (`requests: 500m/2Gi`, `limits: 1000m/4Gi`) to avoid under-provisioned startup crashes.
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
