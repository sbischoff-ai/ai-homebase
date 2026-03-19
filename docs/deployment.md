# Deployment guide landing page

Use this page as the canonical starting point for deploying `ai-homebase`.

## Supported targets

| Target | Best for | Start here |
| --- | --- | --- |
| k3d | Local development, smoke tests, and quick iteration on a workstation. | [k3d deployment flow](./deployment-k3d.md) |
| k3s | Productive homelab deployment on your main server. | [Homelab operations runbook](./runbook-homelab.md) |

## Prerequisites summary

Before choosing a target, confirm:

- Kubernetes + Helm tooling is installed and working.
- Local k3d path has `k3d` and Docker available.
- Local Incus-assisted sandbox path has Incus installed on the host and initialized if you want the bootstrap-managed OpenClaw sandbox VM.
- k3s path has a reachable cluster and a working default storage class.
- You have planned your values overlays and secret references.

## Runbooks

- Local cluster workflow: [docs/deployment-k3d.md](./deployment-k3d.md)
- Productive homelab operations: [docs/runbook-homelab.md](./runbook-homelab.md)

## Install helper

Use `./scripts/install.sh --profile <k3d|k3s>` for supported profile-based installs.
Wrappers `./scripts/install-k3d.sh` and `./scripts/install-k3s.sh` are available for convenience.
