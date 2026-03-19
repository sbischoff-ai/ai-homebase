# Homelab operations runbook

Use this runbook after initial install to operate `ai-homebase` on the supported k3s homelab target.

## 1) Validate before apply

```bash
./scripts/lint.sh --values-file charts/platform-stack/values.yaml
./scripts/lint.sh --values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3s.yaml
```

```bash
./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml > /tmp/platform-stack.yaml
./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3s.yaml > /tmp/platform-stack-k3s.yaml
```

## 2) Deploy or upgrade

```bash
helm dependency update charts/platform-stack
./scripts/install.sh --profile k3s
```

## 3) Health checks

```bash
kubectl -n ai-homebase get pods
kubectl -n ai-homebase get ingress
kubectl -n ai-homebase get pvc
kubectl -n ai-homebase describe ingress
```

## 4) Sandbox posture

The shipped k3s overlay now sets `openclaw.agents.defaults.sandbox.backend=docker` while leaving real Docker runtime enablement for a later change. OpenHands continues to use Kubernetes runtime sandboxes.
