# `k3s` Runbook

Use this guide for the long-running homelab deployment.

## 1. Prepare the Host

On a fresh Ubuntu 24.04 machine:

```bash
sudo ./scripts/install-k3s-ubuntu-2404.sh
```

This script is intended to prepare the host with the baseline tools and services required for the `k3s` bootstrap flow. Review it before use on a real machine.

## 2. Prepare the Bootstrap Config

```bash
cp bootstrap.example.toml bootstrap.local.toml
python3 scripts/bootstrap-config.py validate --config bootstrap.local.toml
```

Fill in:

- service hostnames
- outbound mail settings under `[mail]` for your owned domain
- provider/search API keys
- shared admin identity
- user-provided tokens such as the OpenClaw gateway token and Vaultwarden admin token
- any remote Docker endpoint details that differ from the default target posture

## 3. Bootstrap or Upgrade the Stack

Before bootstrapping OpenClaw itself, create or refresh the standard Incus-backed remote Docker sandbox VM:

```bash
./scripts/k3s-homelab-sandbox-up.sh --bootstrap-config bootstrap.local.toml
```

This uses the same `incus-vm-up.sh` helper as the local path, but with the homelab hostname posture and the current Nextcloud MCP hostname from `bootstrap.local.toml`.

## 4. Bootstrap or Upgrade the Stack

```bash
./scripts/bootstrap-stack.sh --profile k3s --bootstrap-config bootstrap.local.toml
```

This runs the shared secret/bootstrap/apply path:

1. create or refresh bootstrap-managed Secrets
2. render the bootstrap-generated values layer from `bootstrap.local.toml`
3. install or upgrade the Helm release

Before expecting mail delivery from Nextcloud or Vaultwarden on `k3s`, complete the DNS and reverse-DNS steps in [networking.md](./networking.md) for the `[mail]` domain and SMTP hostname.

## 5. Hand Off to GitOps

After the normal `k3s` bootstrap is healthy, the regular next step is to add Argo CD and switch day-two changes to the GitOps repo:

```bash
./scripts/bootstrap-gitops.sh --profile k3s --bootstrap-config bootstrap.local.toml
```

## 6. Verify the Cluster

```bash
kubectl -n ai-homebase get pods
kubectl -n ai-homebase get ingress
kubectl -n ai-homebase get pvc
kubectl -n ai-homebase describe ingress
```

## See Also

- Commands: [commands.md](./commands.md)
- Configuration: [configuration.md](./configuration.md)
- Service contracts: [services.md](./services.md)
- GitOps flow: [gitops.md](./gitops.md)
- Security model: [security.md](./security.md)
- Networking model: [networking.md](./networking.md)
