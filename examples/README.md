# Examples

All examples in this directory use placeholders only. Replace values like `<your-namespace>`, `<your-release>`, and `<your-kube-context>` before running commands.

## Namespace setup

```bash
kubectl --context <your-kube-context> create namespace <your-namespace>
```

## Dummy secrets

```bash
kubectl --context <your-kube-context> -n <your-namespace> create secret docker-registry acr-pull \
  --docker-server=<your-acr-name>.azurecr.io \
  --docker-username=<dummy-username> \
  --docker-password=<dummy-password> \
  --docker-email=<dummy-email@example.com>

kubectl --context <your-kube-context> -n <your-namespace> create secret generic openclaw-app-secrets \
  --from-literal=OPENCLAW_API_KEY=<dummy-openclaw-api-key>

kubectl --context <your-kube-context> -n <your-namespace> create secret generic openhands-app-secrets \
  --from-literal=OPENHANDS_QUEUE_TOKEN=<dummy-queue-token>
```

## Helm install/upgrade examples

```bash
helm dependency update charts/platform-stack

helm upgrade --install <your-release> charts/platform-stack \
  --kube-context <your-kube-context> \
  --namespace <your-namespace> \
  --create-namespace \
  --values charts/platform-stack/values-dev.yaml \
  --values examples/dev.values.override.yaml

helm upgrade --install <your-release> charts/platform-stack \
  --kube-context <your-kube-context> \
  --namespace <your-namespace> \
  --create-namespace \
  --values charts/platform-stack/values-aks.yaml \
  --values examples/aks.values.override.yaml
```

## AKS deployment flow

Use this order for AKS:

1. `kubectl create namespace`.
2. Create `acr-pull` secret when not using managed identity pull.
3. Update placeholders in `examples/aks.values.override.yaml`.
4. Validate render with `scripts/template.sh`.
5. Deploy using `scripts/install-aks.sh`.

```bash
./scripts/template.sh \
  --release-name <your-release> \
  --namespace <your-namespace> \
  --kube-context <your-kube-context> \
  --values-file charts/platform-stack/values-aks.yaml

./scripts/install-aks.sh \
  --release-name <your-release> \
  --namespace <your-namespace> \
  --kube-context <your-kube-context> \
  --values-file charts/platform-stack/values-aks.yaml
```
