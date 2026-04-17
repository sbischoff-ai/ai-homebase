# Deployment Guide

Choose the target first, then stay on that path.

## `k3d`: Local Validation

Use this target when you want the full stack locally for development, smoke testing, and bootstrap validation.

```bash
cp bootstrap.example.toml bootstrap.local.toml
./scripts/k3d-local-bootstrap.sh --cluster-name ai-homebase-dev --bootstrap-config bootstrap.local.toml
```

Continue with [deployment-k3d.md](./deployment-k3d.md).

## `k3s`: Homelab Deployment

Use this target for the long-running server install.

The current intended production target is a single-node `k3s` install on a Hetzner A42U-class host with:

- Ryzen 7 Pro 8700GE
- 64 GB RAM
- roughly 3 TB storage

That target is expected to run the current stack plus leave room for additional heavier services such as Qdrant, a Qdrant MCP service, Memgraph, Memgraph Lab, and future coder-deployed applications. The repo therefore treats single-node `k3s` as the primary near-term deployment posture rather than as a temporary dev environment.

```bash
sudo ./scripts/install-k3s-ubuntu-2404.sh
cp bootstrap.example.toml bootstrap.local.toml
./scripts/k3s-homelab-sandbox-up.sh --bootstrap-config bootstrap.local.toml
./scripts/k3s-homelab-gitea-actions-runner-up.sh --bootstrap-config bootstrap.local.toml
./scripts/bootstrap-stack.sh --profile k3s --bootstrap-config bootstrap.local.toml
```

The k3s prep path expects Docker Engine and git to already be working on the host. It installs k3s with Traefik disabled and installs `ingress-nginx` for the `nginx` ingress class used by rendered manifests.

Continue with [runbook-homelab.md](./runbook-homelab.md).

## Shared Assumptions

- `bootstrap.local.toml` is the operator input for both targets
- `k3d` and `k3s` share the same `bootstrap-stack.sh` secret/bootstrap/apply path after cluster setup
- `k3d` and `k3s` both use `ingress-nginx`; Traefik is not part of the supported target posture
- the normal bootstrap path now includes the GitOps handoff, initial Argo sync, and application-state validation before it returns
- the current `k3s` target is a deliberately single-node system; it is intended to use one stronger server well before any future multi-node expansion
- detailed command catalogs and troubleshooting live outside this page
