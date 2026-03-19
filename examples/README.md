# Examples

All examples in this directory use placeholders only. Replace values like `<your-namespace>`, `<your-release>`, and `<your-kube-context>` before running commands.

## Dummy secrets for all components

```bash
kubectl --context <your-kube-context> -n <your-namespace> create secret generic openclaw-app-secrets \
  --from-literal=OPENCLAW_GATEWAY_TOKEN=<dummy-openclaw-gateway-token>

kubectl --context <your-kube-context> -n <your-namespace> create secret generic openhands-app-secrets \
  --from-literal=LLM_API_KEY=<dummy-llm-api-key>

kubectl --context <your-kube-context> -n <your-namespace> create secret generic openclaw-remote-docker-ssh \
  --from-file=id_ed25519=<path-to-private-key> \
  --from-file=known_hosts=<path-to-known-hosts>
```

## k3d local override layering

Order:

1. `charts/platform-stack/values.yaml`
2. `charts/platform-stack/values-k3d.yaml`
3. `examples/k3d.values.override.yaml` (optional)

```bash
./scripts/template.sh \
  --release-name <your-release> \
  --namespace <your-namespace> \
  --kube-context <your-kube-context> \
  --values-file charts/platform-stack/values.yaml \
  --values-file charts/platform-stack/values-k3d.yaml \
  --values-file examples/k3d.values.override.yaml
```

## k3s homelab override layering

Order:

1. `charts/platform-stack/values.yaml`
2. `charts/platform-stack/values-k3s.yaml`
3. `examples/k3s.values.override.yaml` (optional)

```bash
./scripts/template.sh \
  --release-name <your-release> \
  --namespace <your-namespace> \
  --kube-context <your-kube-context> \
  --values-file charts/platform-stack/values.yaml \
  --values-file charts/platform-stack/values-k3s.yaml \
  --values-file examples/k3s.values.override.yaml
```

## Remote Docker overlay

`examples/openclaw.remote-docker.values.yaml` shows the extra values needed to:

- switch OpenClaw to a derived image that contains Docker CLI + OpenSSH client,
- point `DOCKER_HOST` at a remote Docker daemon over SSH,
- mount the SSH Secret into `/home/node/.ssh`, and
- set the remote browser sandbox image names plus `browser.cdpSourceRange`.

Example layering:

```bash
./scripts/template.sh \
  --release-name <your-release> \
  --namespace <your-namespace> \
  --kube-context <your-kube-context> \
  --values-file charts/platform-stack/values.yaml \
  --values-file charts/platform-stack/values-k3d.yaml \
  --values-file examples/openclaw.remote-docker.values.yaml
```
