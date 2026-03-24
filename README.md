# ai-homebase

`ai-homebase` is a Helm-based homelab stack for running OpenClaw as the center of a personal AI control plane, with supporting services such as Nextcloud, Gitea, Paperless-ngx, Vaultwarden, and an in-cluster Postfix relay for application email.

The point of the repo is not just “a pile of charts.” It gives you one opinionated platform shape that works in two places: `k3d` for fast local iteration and `k3s` for the long-running homelab deployment. The bootstrap flow, secrets model, hostnames, and service posture stay aligned between those targets so local validation is actually useful before you touch the real server.

## Start Here

- Target chooser: [docs/deployment.md](./docs/deployment.md)
- Full docs index: [docs/README.md](./docs/README.md)
- Configuration and bootstrap model: [docs/configuration.md](./docs/configuration.md)
- Service contracts: [docs/services.md](./docs/services.md)

## Quick Start

### Local `k3d`

```bash
cp bootstrap.example.toml bootstrap.local.toml
./scripts/k3d-local-bootstrap.sh --cluster-name ai-homebase-dev --bootstrap-config bootstrap.local.toml
./scripts/bootstrap-gitops.sh --profile k3d --bootstrap-config bootstrap.local.toml
```

Use [docs/deployment-k3d.md](./docs/deployment-k3d.md) for the full local workflow.

### Homelab `k3s`

```bash
sudo ./scripts/install-k3s-ubuntu-2404.sh
cp bootstrap.example.toml bootstrap.local.toml
./scripts/bootstrap-stack.sh --profile k3s --bootstrap-config bootstrap.local.toml
./scripts/bootstrap-gitops.sh --profile k3s --bootstrap-config bootstrap.local.toml
```

Use [docs/runbook-homelab.md](./docs/runbook-homelab.md) for the full host-prep, bootstrap, and post-install path.

In both cases, fill in the new `[mail]` section in `bootstrap.local.toml` before bootstrapping so Nextcloud and Vaultwarden can send mail through the bundled Postfix relay.

## Documentation Map

- Target guides: [docs/deployment-k3d.md](./docs/deployment-k3d.md), [docs/runbook-homelab.md](./docs/runbook-homelab.md)
- Deep dives: [docs/architecture.md](./docs/architecture.md), [docs/security.md](./docs/security.md), [docs/networking.md](./docs/networking.md), [docs/gitops.md](./docs/gitops.md)
- Operational reference: [docs/commands.md](./docs/commands.md), [docs/services.md](./docs/services.md), [docs/storage.md](./docs/storage.md)
- Troubleshooting: [docs/k3d-troubleshooting.md](./docs/k3d-troubleshooting.md)
