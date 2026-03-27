# `k3d` Guide

Use this path for full local validation of the stack, including the shared bootstrap flow that `k3s` uses after cluster setup.

This guide assumes you are running from the repository's `shell.nix` environment. On NixOS, prepare the local prerequisites through `configuration.nix` before using this path.

## 1. Prepare the Bootstrap Config

```bash
cp bootstrap.example.toml bootstrap.local.toml
python3 scripts/bootstrap-config.py validate --config bootstrap.local.toml
```

Fill in:

- service hostnames
- provider/search API keys
- shared admin identity
- user-provided tokens such as `openclaw_gateway_token` and `vaultwarden_admin_token`

## 2. Bootstrap the Local Target

```bash
./scripts/k3d-local-bootstrap.sh --cluster-name ai-homebase-dev --bootstrap-config bootstrap.local.toml
```

This local bootstrap now creates a shared OpenClaw state directory on the host, bind-mounts it into the k3d nodes, and mounts the same directory into the Incus sandbox VM so remote Docker sandboxes see the same `/home/node/.openclaw` tree as the gateway pod.

If you reuse an older k3d cluster that was created before this shared-state bind mount existed, the bootstrap now fails fast with a clear message. In that case, recreate the cluster with:

```bash
./scripts/k3d-down.sh --cluster-name ai-homebase-dev
```

This does three things in order:

1. creates or reuses the local `k3d` cluster
2. boots the Incus-backed remote Docker VM for OpenClaw
3. runs the shared bootstrap/apply flow, then local smoke checks

If you keep the standard Nextcloud MCP service enabled, `scripts/incus-vm-up.sh` now configures the Incus VM and its Docker containers to resolve that MCP ingress hostname to the Incus host listener address automatically. You should only need extra host-side work when the k3d ingress listener itself is not reachable on the Incus bridge address.

If you need a different k3s image for `k3d`, export `K3S_IMAGE` before running the script.

## 3. Access the Services

After a successful bootstrap, the script prints:

- kubeconfig path
- OpenClaw gateway token
- default OpenClaw model, when a model-provider key is configured
- service URLs from `bootstrap.local.toml`

Open the printed OpenClaw URL first. If OpenClaw asks for pairing approval, keep the browser tab open and use the `kubectl exec ... openclaw devices ...` flow below.

## 4. Approve the First OpenClaw Device

List device requests and paired devices:

```bash
kubectl --kubeconfig ~/.kube/k3d-ai-homebase-dev.yaml -n ai-homebase exec -it deploy/platform-stack-openclaw -- openclaw devices list
```

Approve the pending request:

```bash
kubectl --kubeconfig ~/.kube/k3d-ai-homebase-dev.yaml -n ai-homebase exec -it deploy/platform-stack-openclaw -- openclaw devices approve <requestId>
```

## 5. Teardown

```bash
./scripts/k3d-local-teardown.sh --cluster-name ai-homebase-dev --vm-name openclaw-sandbox
```

## 6. GitOps Handoff

After the normal local bootstrap succeeds, the regular next step is to add Argo CD and hand the cluster over to GitOps:

```bash
./scripts/bootstrap-gitops.sh --profile k3d --bootstrap-config bootstrap.local.toml
```

## See Also

- Commands: [commands.md](./commands.md)
- Networking and local host access: [networking.md](./networking.md)
- GitOps flow: [gitops.md](./gitops.md)
- Deep troubleshooting: [k3d-troubleshooting.md](./k3d-troubleshooting.md)
- Configuration details: [configuration.md](./configuration.md)
