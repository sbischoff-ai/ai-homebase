# k3d local deployment workflow

Use this guide when you want to validate the supported local `k3d` target together with the Incus-backed OpenClaw sandbox VM.

## 1) Bootstrap the local environment

```bash
export OPENAI_API_KEY="<your-openai-api-key>"
./scripts/k3d-local-bootstrap.sh --cluster-name ai-homebase-dev
```

This workflow:

- Creates or reuses a local `k3d` cluster.
- Boots the Incus-backed `openclaw-sandbox` VM used by the standard remote Docker posture.
- Generates the required Kubernetes Secrets.
- Deploys `platform-stack` with `charts/platform-stack/values.yaml` and `charts/platform-stack/values-k3d.yaml`.
- Runs the local smoke checks.

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
- The local smoke check waits up to 600 seconds for each deployment rollout/readiness check so slower first boots do not fail just before OpenClaw becomes Ready.
- If you only need generic install, lint, template, or helper-script commands outside this k3d-specific workflow, use [`docs/commands.md`](./commands.md).

## 3) Service access

Expected local browser endpoints served by the k3d `ingress-nginx` controller:

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
127.0.0.1 infisical.localtest.me openclaw.localtest.me
```

## 6) When to override defaults

Use the default `values.yaml + values-k3d.yaml` layering unless you have a concrete local need such as:

- Pointing OpenClaw at a different resolved remote Docker SSH endpoint
- Enabling optional local services such as Nextcloud or Paperless with matching local hostnames
- Extending VM readiness timeouts on slower machines
- Debugging Incus guest bootstrap, bridge DNS, or SSH readiness problems

For those cases, keep the main workflow above and use the detailed notes in [`docs/k3d-troubleshooting.md`](./k3d-troubleshooting.md).
