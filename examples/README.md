# Examples

All examples in this directory use placeholders only. Replace values like `<your-namespace>`, `<your-release>`, and `<your-kube-context>` before running commands.

## Dummy secrets for all components

```bash
kubectl --context <your-kube-context> -n <your-namespace> create secret generic openclaw-app-secrets \
  --from-literal=OPENCLAW_GATEWAY_TOKEN=<dummy-openclaw-gateway-token>

kubectl --context <your-kube-context> -n <your-namespace> create secret generic openhands-app-secrets \
  --from-literal=LLM_API_KEY=<dummy-llm-api-key>
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
