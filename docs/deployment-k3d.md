# `k3d` Guide

Use this path for full local validation of the stack, including the shared bootstrap flow that `k3s` uses after cluster setup.

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

This does three things in order:

1. creates or reuses the local `k3d` cluster
2. boots the Incus-backed remote Docker VM for OpenClaw
3. runs the shared bootstrap/install flow, then local smoke checks

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

## 6. Optional GitOps Handoff

After the normal local bootstrap succeeds, you can add Argo CD and hand the cluster over to GitOps:

```bash
./scripts/bootstrap-gitops.sh --profile k3d --bootstrap-config bootstrap.local.toml
```

## See Also

- Commands: [commands.md](./commands.md)
- Networking and local host access: [networking.md](./networking.md)
- GitOps flow: [gitops.md](./gitops.md)
- Deep troubleshooting: [k3d-troubleshooting.md](./k3d-troubleshooting.md)
- Configuration details: [configuration.md](./configuration.md)
