# k3d local deployment flow

This guide describes the local `k3d` workflow for `platform-stack`, including cluster bootstrap, deploy/smoke checks, ingress host access, and common troubleshooting.

## 0) Prerequisites

Install and verify:

- [k3d](https://k3d.io/)
- [Docker](https://docs.docker.com/get-docker/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm 3](https://helm.sh/docs/intro/install/)

## 1) Recommended bootstrap

```bash
export OPENAI_API_KEY="<your-openai-api-key>"
./scripts/k3d-local-bootstrap.sh --cluster-name ai-homebase-dev
```

This flow:

- creates or reuses the k3d cluster,
- installs ingress-nginx,
- generates bootstrap secrets,
- deploys `platform-stack` with `values.yaml + values-k3d.yaml`, and
- runs local smoke checks.

## 2) Manual flow

### 2.1 Bootstrap the local cluster

```bash
./scripts/k3d-up.sh --cluster-name ai-homebase-dev
```

`k3d-up.sh` disables the bundled k3s Traefik deployment so `ingress-nginx` remains the only intended HTTP/HTTPS ingress controller in the local cluster. It also mounts the host machine Docker socket into every k3d node container at `/var/run/docker.sock`, which keeps the existing OpenClaw pod `hostPath` mount working inside k3d.

### 2.2 Generate bootstrap secrets

```bash
export OPENAI_API_KEY="<your-openai-api-key>"
./scripts/k3d-bootstrap-secrets.sh \
  --namespace ai-homebase \
  --release-name platform-stack \
  --kubeconfig ~/.kube/k3d-ai-homebase-dev.yaml
```

### 2.3 Deploy and run smoke checks

```bash
./scripts/test-local-k3d.sh \
  --release-name platform-stack \
  --namespace ai-homebase \
  --kubeconfig ~/.kube/k3d-ai-homebase-dev.yaml
```

If you only want the install step:

```bash
./scripts/install.sh --profile k3d
```

Default values layers used by the k3d scripts:

1. `charts/platform-stack/values.yaml`
2. `charts/platform-stack/values-k3d.yaml`

## 3) Service access

Expected local browser endpoints served by the k3d `ingress-nginx` controller:

- `http://wg.localtest.me`
- `http://openhands.localtest.me`
- `http://infisical.localtest.me`

`openclaw` remains service-only by default in the shipped k3d layering.

## 4) Local ingress host access (DNS/hosts)

`*.localtest.me` usually resolves to `127.0.0.1` automatically.
If not, add entries such as:

```text
127.0.0.1 openhands.localtest.me wg.localtest.me infisical.localtest.me openclaw.localtest.me
```

## 5) Sandbox note

The k3d overlay keeps OpenClaw on Docker-socket-backed sandboxing for trusted local testing, but OpenHands now uses the upstream in-cluster Kubernetes runtime. OpenHands therefore no longer mounts `/var/run/docker.sock`; instead it creates per-session runtime pods, services, ingresses, and PVCs in the cluster using its namespace-scoped RBAC.
