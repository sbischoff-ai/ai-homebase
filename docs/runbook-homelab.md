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

OpenClaw now ships with a Docker sandbox configuration that is standardized on a remote Docker daemon reached through Docker's SSH transport. The chart exposes structured values for the sandbox images, browser/CDP network policy, and the required remote-Docker SSH wiring inside the OpenClaw pod. OpenHands runs as a lightweight in-cluster control plane that launches per-session **Kubernetes runtime** sandboxes inside the cluster.

The shared OpenClaw defaults now render Docker/browser sandbox settings directly in `openclaw.json`. Keep `openclaw.remoteDocker.*` enabled, provide an SSH Secret plus an OpenClaw image with Docker CLI/OpenSSH, and set `openclaw.agents.defaults.sandbox.browser.cdpSourceRange` for the network range seen by the remote Docker host. The shipped k3s overlay assumes the remote Incus VM is reachable at `ssh://docker-remote@openclaw-sandbox.homebase.internal:2222`; override that host if your homelab uses a different DNS name or routed IP. OpenHands continues to use Kubernetes runtime sandboxes.
