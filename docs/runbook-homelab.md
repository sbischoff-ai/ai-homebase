# `k3s` Runbook

Use this guide for the long-running homelab deployment.

## Target Host

The current intended host profile is:

- Hetzner A42U-class machine
- Ryzen 7 Pro 8700GE
- 64 GB RAM
- roughly 3 TB storage

This repo currently assumes a single-node `k3s` deployment on that class of machine is the main production target. The sizing posture should therefore leave headroom for the existing stack, the OpenClaw remote sandbox VM, and additional future services such as Qdrant, Qdrant MCP, Memgraph, Memgraph Lab, and coder-deployed web services.

The single-node tradeoff is deliberate: the platform is meant to be operationally simple first, not highly available yet.

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
It also mounts the shared OpenClaw state directory into the Incus VM at `/home/node/.openclaw` so remote Docker sandboxes see the same workspace and sandbox staging tree as the gateway pod.

## 4. Bootstrap or Upgrade the Stack

```bash
./scripts/bootstrap-stack.sh --profile k3s --bootstrap-config bootstrap.local.toml
```

This runs the shared secret/bootstrap/apply path:

1. create or refresh bootstrap-managed Secrets
2. render the bootstrap-generated values layer from `bootstrap.local.toml`
3. install or upgrade the Helm release
4. hand the cluster over to the in-cluster GitOps repo, trigger the initial Argo sync, and validate the Argo application states

Before expecting mail delivery from Nextcloud or Vaultwarden on `k3s`, complete the DNS and reverse-DNS steps in [networking.md](./networking.md) for the `[mail]` domain and SMTP hostname.

The shipped `k3s` overlay now carries more explicit resource requests and limits than the local target because this homelab posture is expected to consolidate several stateful services on one host while still leaving room for future additions.

## 5. GitOps Rerun

The normal `k3s` bootstrap now already adds Argo CD and completes the first GitOps sync/validation pass.

Re-run `./scripts/bootstrap-gitops.sh --profile k3s --bootstrap-config bootstrap.local.toml` only when you intentionally need to refresh the in-cluster GitOps repo snapshot from the current working tree without re-running the full bootstrap flow. If you created the homelab sandbox VM with the default Incus state path, `bootstrap-gitops.sh` reuses the same remote-Docker connection info and SSH key path as `bootstrap-stack.sh`. You only need to pass `--remote-docker-key` explicitly when you diverged from the standard key location.

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
