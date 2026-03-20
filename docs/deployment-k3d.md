# k3d local deployment flow

This guide keeps the supported local `k3d` operator path up front. Detailed Incus, cloud-init, networking, and deep-dive troubleshooting notes live in [`docs/k3d-troubleshooting.md`](./k3d-troubleshooting.md).

## 0) Prerequisites

Install and verify:

- [k3d](https://k3d.io/)
- [Docker](https://docs.docker.com/get-docker/)
- [Incus](https://linuxcontainers.org/incus/) installed on the host, with an initialized local daemon, a bridge network (the bootstrap assumes `incusbr0` by default), and storage/profile defaults that can boot a VM
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm 3](https://helm.sh/docs/intro/install/)

Required operator inputs before you start:

- `OPENAI_API_KEY` for the local bootstrap Secret generation flow
- Permission to run local `docker`, `k3d`, `kubectl`, `helm`, and `incus` commands on the workstation

Expected runtime:

- `./scripts/k3d-local-bootstrap.sh` is usually the fastest supported path, but the first run can take several minutes because the Incus VM installs Docker Engine and SSH during guest bootstrap.

## 1) Recommended bootstrap

Run this when you want the shortest supported path:

```bash
export OPENAI_API_KEY="<your-openai-api-key>"
./scripts/k3d-local-bootstrap.sh --cluster-name ai-homebase-dev
```

### What the bootstrap does

- Creates or reuses the local `k3d` cluster
- Creates or reuses the dedicated Incus VM used for OpenClaw remote Docker sandboxing
- Installs `ingress-nginx`
- Generates bootstrap Secrets, including the remote Docker SSH material
- Deploys `platform-stack` with `charts/platform-stack/values.yaml` and `charts/platform-stack/values-k3d.yaml`
- Runs local smoke checks

### Operator decision points

- Use this path when you want an end-to-end local install with the repository defaults.
- If the first run is slow, let it finish before assuming failure; the guest VM may still be completing cloud-init.
- If you need to customize the OpenClaw remote Docker endpoint or debug bootstrap internals, switch to the manual flow below and then use [`docs/k3d-troubleshooting.md`](./k3d-troubleshooting.md).

## 2) Manual flow

Use this path when you need to inspect or override each step.

### 2.1 Bootstrap the local cluster

```bash
./scripts/k3d-up.sh --cluster-name ai-homebase-dev
./scripts/incus-vm-up.sh --vm-name openclaw-sandbox
source ~/.local/state/ai-homebase/incus/openclaw-sandbox.env
```

What you need to know:

- `k3d-up.sh` disables the bundled k3s Traefik deployment so `ingress-nginx` remains the intended ingress controller.
- `incus-vm-up.sh` can take a few minutes on the first run while the VM becomes SSH-ready.
- The sourced env file supplies the resolved host/port values for the next command.

### 2.2 Generate bootstrap secrets

```bash
export OPENAI_API_KEY="<your-openai-api-key>"
./scripts/k3d-bootstrap-secrets.sh \
  --namespace ai-homebase \
  --release-name platform-stack \
  --kubeconfig ~/.kube/k3d-ai-homebase-dev.yaml \
  --remote-docker-host "$HOST_LISTEN_ADDRESS" \
  --remote-docker-port "$SSH_HOST_PORT" \
  --remote-docker-key ~/.local/state/ai-homebase/incus/openclaw-sandbox-id_ed25519
```

What you need to know:

- This step requires the OpenAI API key plus the SSH endpoint exported by the Incus helper.
- The helper fails early when the remote Docker private key or generated `known_hosts` data is missing, so fix that before deploying.

If you need the Helm release to target the same resolved remote Docker endpoint explicitly, create a one-off override file:

```bash
cat >/tmp/platform-stack-k3d-remote-docker.yaml <<EOF2
openclaw:
  remoteDocker:
    dockerHost: ssh://docker-remote@${HOST_LISTEN_ADDRESS}:${SSH_HOST_PORT}
EOF2
```

### 2.3 Deploy and run smoke checks

```bash
./scripts/test-local-k3d.sh \
  --release-name platform-stack \
  --namespace ai-homebase \
  --kubeconfig ~/.kube/k3d-ai-homebase-dev.yaml \
  --values-file /tmp/platform-stack-k3d-remote-docker.yaml
```

What you need to know:

- The k3d scripts use `charts/platform-stack/values.yaml` plus `charts/platform-stack/values-k3d.yaml` by default.
- Use this command after secrets are in place and any one-off override file is ready.
- If you only need generic install, lint, template, or helper-script commands outside this k3d-specific workflow, use [`docs/commands.md`](./commands.md).

## 3) Service access

Expected local browser endpoints served by the k3d `ingress-nginx` controller:

- `http://openhands.localtest.me`
- `http://infisical.localtest.me`
- `http://openclaw.localtest.me`

## 4) Teardown

Remove both the local cluster and the Incus VM together:

```bash
./scripts/k3d-local-teardown.sh --cluster-name ai-homebase-dev --vm-name openclaw-sandbox
```

## 5) Local ingress host access

`*.localtest.me` usually resolves to `127.0.0.1` automatically.
If it does not, add entries such as:

```text
127.0.0.1 openhands.localtest.me infisical.localtest.me openclaw.localtest.me
```

## 6) When to override defaults

Use the default `values.yaml + values-k3d.yaml` layering unless you have a concrete local need such as:

- Pointing OpenClaw at a different resolved remote Docker SSH endpoint
- Enabling optional local services such as Nextcloud or Paperless with matching local hostnames
- Extending VM readiness timeouts on slower machines
- Debugging Incus guest bootstrap, bridge DNS, or SSH readiness problems

For those cases, keep the main workflow above and use the detailed notes in [`docs/k3d-troubleshooting.md`](./k3d-troubleshooting.md).
