# ai-homebase

`ai-homebase` is an opinionated homelab platform for running OpenClaw as the center of a personal AI control plane. It combines a multi-agent OpenClaw setup with supporting services such as Nextcloud, a dedicated Nextcloud MCP gateway, Gitea, Paperless-ngx, Vaultwarden, shared PostgreSQL/Redis, and an in-cluster Postfix relay for application email.

The point of the repo is not just “a pile of charts.” It gives you one coherent platform shape that works in two places: `k3d` for fast local iteration and `k3s` for the long-running homelab deployment. The bootstrap flow, secrets model, hostnames, multi-agent topology, MCP posture, and service contracts stay aligned between those targets so local validation is actually useful before you touch the real server.

Characteristic features of this stack:

- OpenClaw bootstrapped as a multi-agent system with `main`, `architect`, and `coder`
- remote Docker sandboxes for specialist agents, including a coder-specific sandbox image with developer tooling
- Nextcloud shared with OpenClaw through a dedicated MCP gateway and shared-account operating conventions
- GitOps handoff into an in-cluster Gitea repository with Argo CD kept in manual-sync mode
- one bootstrap input model for both local and homelab targets through `bootstrap.local.toml`

The intended long-running target today is a single-node `k3s` install on a Hetzner A42U-class machine with a Ryzen 7 Pro 8700GE, 64 GB RAM, and roughly 3 TB of storage. The repo now assumes that target should have headroom not only for the current stack, but also for additional heavier services such as Qdrant, Memgraph, and future coder-deployed web services.

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

Use [docs/deployment-k3d.md](./docs/deployment-k3d.md) for the full local workflow, including the required NixOS host preparation and the GitOps handoff that normally follows a healthy local bootstrap.

### Homelab `k3s`

```bash
sudo ./scripts/install-k3s-ubuntu-2404.sh
cp bootstrap.example.toml bootstrap.local.toml
./scripts/bootstrap-stack.sh --profile k3s --bootstrap-config bootstrap.local.toml
./scripts/bootstrap-gitops.sh --profile k3s --bootstrap-config bootstrap.local.toml
```

Use [docs/runbook-homelab.md](./docs/runbook-homelab.md) for the full Ubuntu host-prep, bootstrap, and GitOps handoff path.

In both cases, fill in the new `[mail]` section and the per-agent model sections in `bootstrap.local.toml` before bootstrapping so Nextcloud/Vaultwarden mail and the bootstrapped OpenClaw `main`, `architect`, and `coder` agents are configured correctly. The same bootstrap flow also creates a dedicated `openclaw` Nextcloud user, seeds the OpenClaw gateway config with the standard Nextcloud MCP server definition, and pre-seeds specialist workspace files for the multi-agent topology.

## Documentation Map

- Target guides: [docs/deployment-k3d.md](./docs/deployment-k3d.md), [docs/runbook-homelab.md](./docs/runbook-homelab.md)
- Deep dives: [docs/architecture.md](./docs/architecture.md), [docs/security.md](./docs/security.md), [docs/networking.md](./docs/networking.md), [docs/gitops.md](./docs/gitops.md)
- Operational reference: [docs/commands.md](./docs/commands.md), [docs/services.md](./docs/services.md), [docs/storage.md](./docs/storage.md)
- Troubleshooting: [docs/k3d-troubleshooting.md](./docs/k3d-troubleshooting.md)
