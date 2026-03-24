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

```bash
sudo ./scripts/install-k3s-ubuntu-2404.sh
cp bootstrap.example.toml bootstrap.local.toml
./scripts/bootstrap-stack.sh --profile k3s --bootstrap-config bootstrap.local.toml
```

Continue with [runbook-homelab.md](./runbook-homelab.md).

## Shared Assumptions

- `bootstrap.local.toml` is the operator input for both targets
- `k3d` and `k3s` share the same secret/bootstrap/install path after cluster setup
- detailed command catalogs and troubleshooting live outside this page
