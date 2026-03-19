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

`openclaw-remote-docker-ssh` is part of the standard OpenClaw deployment posture in this repo; every supported target needs an equivalent Secret even if you override the name in values.

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

`examples/openclaw.remote-docker.values.yaml` shows the environment-specific values you may still need to adjust on top of the standard remote-Docker posture to:

- switch OpenClaw to an image that contains Docker CLI + OpenSSH client,
- change `DOCKER_HOST` when your Incus VM is not reachable at the shipped target default,
- change the SSH Secret name or mount path, and
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
