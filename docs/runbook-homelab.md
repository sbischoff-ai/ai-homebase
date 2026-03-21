# Homelab operations runbook

Use this runbook after initial install to operate `ai-homebase` on the supported k3s homelab target.

## 1) Validate before apply

Run the canonical lint and render commands from [`docs/commands.md`](./commands.md), especially the `k3s` profile entries, before each apply.

## 2) Deploy or upgrade

Use the homelab entry command:

```bash
./scripts/install.sh --profile k3s
```

For dependency refresh and alternate install wrappers, use [`docs/commands.md`](./commands.md). When `certManager.enabled=true`, `./scripts/install.sh` automatically does a two-step bootstrap so the first apply installs the cert-manager CRDs/controller stack before the chart renders the internal PKI and OpenClaw certificate resources.

## 3) Health checks

```bash
kubectl -n ai-homebase get pods
kubectl -n ai-homebase get ingress
kubectl -n ai-homebase get pvc
kubectl -n ai-homebase describe ingress
```

## 4) Sandbox posture

OpenClaw ships with a Docker sandbox configuration that is standardized on a remote Docker daemon reached through Docker's SSH transport. The chart exposes structured values for the sandbox images, browser/CDP network policy, and the required remote-Docker SSH wiring inside the OpenClaw pod.

The shared OpenClaw defaults now render Docker/browser sandbox settings directly in `openclaw.json`. Keep `openclaw.remoteDocker.*` enabled, provide an SSH Secret plus an OpenClaw image with Docker CLI/OpenSSH, and set `openclaw.agents.defaults.sandbox.browser.cdpSourceRange` for the network range seen by the remote Docker host. The shipped k3s overlay assumes the remote Incus VM is reachable at `ssh://docker-remote@openclaw-sandbox.homebase.internal:2222`; override that host if your homelab uses a different DNS name or routed IP.
