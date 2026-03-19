# k3d local deployment flow

This guide describes the local `k3d` workflow for `platform-stack`, including cluster bootstrap, deploy/smoke checks, ingress host access, and common troubleshooting.

## 0) Prerequisites

Install and verify:

- [k3d](https://k3d.io/)
- [Docker](https://docs.docker.com/get-docker/)
- [Incus](https://linuxcontainers.org/incus/) installed on the host, with an initialized local daemon/bridge (the bootstrap assumes the default `incusbr0` network)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm 3](https://helm.sh/docs/intro/install/)

## 1) Recommended bootstrap

```bash
export OPENAI_API_KEY="<your-openai-api-key>"
./scripts/k3d-local-bootstrap.sh --cluster-name ai-homebase-dev
```

This flow:

- creates or reuses the k3d cluster,
- creates or reuses a dedicated Incus VM for remote Docker sandboxing,
- installs ingress-nginx,
- generates bootstrap secrets,
- deploys `platform-stack` with `values.yaml + values-k3d.yaml`, and
- runs local smoke checks.

The bootstrap exports `KUBECONFIG` to the dedicated kubeconfig path for the lifetime of the script so nested `kubectl` and `helm` calls all target the same local cluster.
The companion Incus VM is intentionally minimal: `images:debian/12/cloud`, **2 vCPU**, **6 GiB RAM**, a 12 GiB root disk, Docker Engine, and SSH. The bootstrap now applies the root disk size as an instance-level device override so it works even when the `default` Incus profile provides the root disk device. Instead of exposing the Docker daemon over unauthenticated TCP, the bootstrap configures SSH access, creates the `openclaw-remote-docker-ssh` Secret, and points OpenClaw at `ssh://docker-remote@host.k3d.internal:2222` through Docker's SSH transport by default.

## 2) Manual flow

### 2.1 Bootstrap the local cluster

```bash
./scripts/k3d-up.sh --cluster-name ai-homebase-dev
./scripts/incus-vm-up.sh --vm-name openclaw-sandbox
```

`k3d-up.sh` disables the bundled k3s Traefik deployment so `ingress-nginx` remains the only intended HTTP/HTTPS ingress controller in the local cluster. k3d itself still runs on Docker to host the local cluster.

### 2.2 Generate bootstrap secrets

```bash
export OPENAI_API_KEY="<your-openai-api-key>"
./scripts/k3d-bootstrap-secrets.sh \
  --namespace ai-homebase \
  --release-name platform-stack \
  --kubeconfig ~/.kube/k3d-ai-homebase-dev.yaml \
  --remote-docker-host host.k3d.internal \
  --remote-docker-key ~/.local/state/ai-homebase/incus/openclaw-sandbox-id_ed25519
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

To tear down both the cluster and the Incus VM together:

```bash
./scripts/k3d-local-teardown.sh --cluster-name ai-homebase-dev --vm-name openclaw-sandbox
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

### NixOS host setup notes

If you use NixOS and want the Incus-backed sandbox VM flow, make sure Incus is enabled on the host rather than relying on the repository's `shell.nix`. Add the equivalent host configuration for your system, including:

```nix
virtualisation.incus.enable = true;
networking.nftables.enable = true;
users.users.<your-user>.extraGroups = [ "incus-admin" ];
```

After rebuilding your NixOS configuration, initialize Incus if needed and then continue with the k3d bootstrap flow above.

## 5) Sandbox note

The shared OpenClaw defaults now render the Docker sandbox backend with explicit `docker.*` and `browser.*` settings, and the supported path keeps remote-Docker wiring enabled by default. Operators still need an OpenClaw image that includes Docker CLI + OpenSSH client and an environment-appropriate `browser.cdpSourceRange`. OpenHands continues to use the upstream in-cluster Kubernetes runtime.

## 6) Incus sandbox VM note

The Incus VM assets live outside the Helm charts:

- `incus/openclaw-sandbox-user-data.tpl` contains the cloud-init definition for the guest.
- `scripts/incus-vm-up.sh` creates or reuses the VM and configures SSH-based remote Docker access.
- `scripts/incus-vm-down.sh` deletes just the VM.
- `scripts/k3d-local-teardown.sh` removes both the k3d cluster and the Incus VM.

This keeps the VM independently managed from Helm while still making it part of the local bootstrap lifecycle.
