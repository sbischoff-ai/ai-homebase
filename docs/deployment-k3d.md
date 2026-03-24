# k3d local deployment workflow

Use this guide when you want to validate the supported local `k3d` target together with the Incus-backed OpenClaw sandbox VM.

## 1) Bootstrap the local environment

```bash
export OPENAI_API_KEY="<your-openai-api-key>"
# or export ANTHROPIC_API_KEY / GEMINI_API_KEY / XAI_API_KEY / MOONSHOT_API_KEY
# optionally add BRAVE_API_KEY / PERPLEXITY_API_KEY for built-in web search
./scripts/k3d-local-bootstrap.sh --cluster-name ai-homebase-dev
```

This workflow:

- Creates or reuses a local `k3d` cluster.
- Pins the local cluster to a Kubernetes 1.32-compatible k3s image by default instead of relying on the `k3d` binary's built-in default.
- Boots the Incus-backed `openclaw-sandbox` VM used by the standard remote Docker posture.
- Generates the required Kubernetes Secrets from any exported supported OpenClaw provider/search keys (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `BRAVE_API_KEY`, `PERPLEXITY_API_KEY`, `GEMINI_API_KEY`, `XAI_API_KEY`, `MOONSHOT_API_KEY`).
- Creates or refreshes the shared-service Secrets for Gitea, Vaultwarden, Nextcloud, and Paperless so each app gets its own dedicated PostgreSQL role/database credentials while Nextcloud, Gitea, and Paperless also use the shared Redis service.
- Writes the matching OpenClaw secret key mappings only for the provider/search env vars you actually exported, so unset optional keys are not requested from Kubernetes at pod startup.
- Deploys `platform-stack` with `charts/platform-stack/values.yaml` and `charts/platform-stack/values-k3d.yaml`.
- Runs the local smoke checks.

If you need to override the pinned k3s image for local testing, export `K3S_IMAGE` before running the bootstrap:

```bash
export K3S_IMAGE="rancher/k3s:v1.32.11-k3s1"
./scripts/k3d-local-bootstrap.sh --cluster-name ai-homebase-dev
```

## 2) Advanced: custom remote Docker endpoint override

If the remote Docker endpoint needs a one-off override, generate a small overlay file and pass it into the smoke test command.

```bash
cat >/tmp/platform-stack-k3d-remote-docker.yaml <<EOF2
openclaw:
  remoteDocker:
    dockerHost: ssh://docker-remote@${HOST_LISTEN_ADDRESS}:${SSH_HOST_PORT}
EOF2
```

### 2.3 Deploy and run smoke checks

```bash
./scripts/test-local-k3d.sh   --release-name platform-stack   --namespace ai-homebase   --kubeconfig ~/.kube/k3d-ai-homebase-dev.yaml   --values-file /tmp/platform-stack-k3d-remote-docker.yaml
```

What you need to know:

- The k3d scripts use `charts/platform-stack/values.yaml` plus `charts/platform-stack/values-k3d.yaml` by default.
- Use this command after secrets are in place and any one-off override file is ready.
- The local smoke check now uses per-service rollout/readiness deadlines so slower first boots do not fail while larger images and init chains are still converging: `OPENCLAW_WAIT_TIMEOUT=600s`, `NEXTCLOUD_WAIT_TIMEOUT=1200s`, `VAULTWARDEN_WAIT_TIMEOUT=900s`, `GITEA_WAIT_TIMEOUT=1200s`, and `PAPERLESS_WAIT_TIMEOUT=1200s` by default. Override those env vars if your machine needs different local validation timing.
- If you only need generic install, lint, template, or helper-script commands outside this k3d-specific workflow, use [`docs/commands.md`](./commands.md).

## 3) Service access

Expected local browser endpoints served by the k3d `ingress-nginx` controller:

- `http://gitea.localtest.me`
- `http://nextcloud.localtest.me`
- `http://vaultwarden.localtest.me`
- `http://paperless.localtest.me`
- `http://openclaw.localtest.me`

After a successful bootstrap, the summary output prints:

- the kubeconfig path used for the cluster
- the OpenClaw gateway token that was written into `openclaw-app-secrets`
- the auto-selected default OpenClaw model when a model-provider key was exported
- the local service URLs for OpenClaw, Nextcloud, Gitea, Vaultwarden, and Paperless

## 4) First-use OpenClaw token and device pairing

When you first open OpenClaw in a browser:

1. Browse to `http://openclaw.localtest.me`.
2. Paste the **OpenClaw gateway token** from the bootstrap summary into the Control UI settings if prompted.
3. If OpenClaw shows **pairing required**, keep that browser tab open and approve the device from Kubernetes with `kubectl`.

List device requests and currently paired devices:

```bash
kubectl --kubeconfig ~/.kube/k3d-ai-homebase-dev.yaml -n ai-homebase exec -it deploy/platform-stack-openclaw -- openclaw devices list
```

Approve the pending request:

```bash
kubectl --kubeconfig ~/.kube/k3d-ai-homebase-dev.yaml -n ai-homebase exec -it deploy/platform-stack-openclaw -- openclaw devices approve <requestId>
```

Notes:

- Replace the kubeconfig path if you bootstrapped with a different `--cluster-name` or `--kubeconfig`.
- If `devices list` shows only paired devices and no pending request, clear browser site data for `openclaw.localtest.me`, reopen the printed OpenClaw URL, and then re-run `devices list` while the pairing screen is still open.

## 5) Teardown

Remove both the local cluster and the Incus VM together:

```bash
./scripts/k3d-local-teardown.sh --cluster-name ai-homebase-dev --vm-name openclaw-sandbox
```

## 6) Local ingress host access

`*.localtest.me` usually resolves to `127.0.0.1` automatically.
If it does not, add entries such as:

```text
127.0.0.1 gitea.localtest.me nextcloud.localtest.me vaultwarden.localtest.me paperless.localtest.me openclaw.localtest.me
```

## 7) When to override defaults

Use the default `values.yaml + values-k3d.yaml` layering unless you have a concrete local need such as:

- Pointing OpenClaw at a different resolved remote Docker SSH endpoint
- Extending or overriding the shipped local Nextcloud/Paperless posture with different hostnames, storage, or service toggles
- Extending VM readiness timeouts on slower machines
- Debugging Incus guest bootstrap, bridge DNS, or SSH readiness problems

For those cases, keep the main workflow above and use the detailed notes in [`docs/k3d-troubleshooting.md`](./k3d-troubleshooting.md).
