# `k3s` Homelab Runbook

Use this guide for the long-running single-node homelab deployment.

## Target Host

The current intended host profile is:

- Hetzner A42U-class machine
- Ryzen 7 Pro 8700GE
- 64 GB RAM
- roughly 3 TB storage

The single-node tradeoff is deliberate: operational simplicity comes before high availability for this generation of the stack.

## Preflight

Confirm before running bootstrap on the server:

- Ubuntu 24.04 host is fresh enough that disabling Traefik will not disrupt other workloads.
- Docker Engine works on the host.
- `git` works on the host.
- DNS for the chosen service hostnames points where the runbook expects.
- Outbound mail DNS and reverse DNS are ready for the `[mail]` domain if app mail should work immediately.
- `bootstrap.local.toml` has been filled and validated.
- You understand that this repository bootstraps the first install; GitOps and durable service state take over after handoff.

The host-prep script intentionally does not install Docker or git. They are operator-owned host prerequisites because image builds, local image publishing, and GitOps pushes depend on the operator's chosen host setup.

## 1. Prepare k3s

```bash
sudo ./scripts/install-k3s-ubuntu-2404.sh
```

The script installs/starts k3s with Traefik disabled, installs or upgrades `ingress-nginx`, and waits for the `nginx` ingress controller to become ready. Rendered k3s manifests should not rely on a Traefik ingress class.

## 2. Prepare Bootstrap Config

```bash
cp bootstrap.example.toml bootstrap.local.toml
python3 scripts/bootstrap-config.py validate --config bootstrap.local.toml
```

Fill in hostnames, mail settings, provider keys, shared admin details, OpenClaw gateway token, Vaultwarden admin token, registry credentials if desired, and GitOps/coder overrides if the defaults are not what you want.

## 3. Prepare OpenClaw Sandbox VM

```bash
./scripts/k3s-homelab-sandbox-up.sh --bootstrap-config bootstrap.local.toml
```

This creates or refreshes the Incus-backed remote Docker VM, mounts `/var/lib/ai-homebase/openclaw-state` into the VM at `/home/node/.openclaw`, and configures hostname resolution for the canonical set of bootstrap-config service hostnames that sandboxed agents may reach through ingress.

## 4. Prepare Gitea Actions Runner VM

```bash
./scripts/k3s-homelab-gitea-actions-runner-up.sh --bootstrap-config bootstrap.local.toml
```

Gitea Actions are enabled by default, so the standard homelab path prepares a second Incus VM for the dedicated runner. Skip this only when you explicitly disable Actions in `bootstrap.local.toml`.

## 5. Bootstrap The Stack

```bash
./scripts/bootstrap-stack.sh --profile k3s --bootstrap-config bootstrap.local.toml
```

The shared bootstrap path creates Secrets, renders the generated bootstrap values layer, builds/imports the repo-managed OpenClaw gateway image, installs the Helm release, exports the internal CA bundle, publishes runtime images where required, hands the cluster to Gitea/Argo CD, triggers the first sync, and waits for Argo applications to report `Synced` and `Healthy`.

Bootstrap-side Gitea API and git operations use a local port-forward to the in-cluster Gitea service, so the first install does not depend on the host trusting the internal ingress CA.

## 6. Confidence Checks

After bootstrap returns, run:

```bash
kubectl -n ai-homebase get pods
kubectl -n ai-homebase get ingress
kubectl -n ai-homebase get pvc
kubectl -n ai-homebase get applications.argoproj.io
kubectl -n ingress-nginx get pods
kubectl -n kube-system get deploy traefik
```

Expected results:

- `ai-homebase` pods are ready or completed.
- ingresses use the `nginx` class.
- PVCs are bound with the expected `local-path` sizes.
- Argo CD applications are `Synced` and `Healthy`.
- ingress-nginx controller pods are ready.
- `kubectl -n kube-system get deploy traefik` returns not found on a fresh host prepared by this repo.

For rendered preflight confidence before touching the server, use:

```bash
./scripts/template.sh \
  --release-name platform-stack \
  --namespace ai-homebase \
  --values-file charts/platform-stack/values.yaml \
  --values-file charts/platform-stack/values-k3s.yaml \
  > /tmp/platform-stack-k3s.yaml

rg -n "traefik" /tmp/platform-stack-k3s.yaml
rg -n 'image: "openclaw-remote-docker:trixie-slim"' /tmp/platform-stack-k3s.yaml
```

The first `rg` should produce no Traefik ingress dependency; the second should find the OpenClaw Deployment image.

## GitOps Refresh

The normal `k3s` bootstrap already creates the GitOps repo, enables Argo CD, syncs, and validates application state. Re-run this only when you intentionally need to refresh the in-cluster GitOps repo snapshot from the current working tree:

```bash
./scripts/bootstrap-gitops.sh --profile k3s --bootstrap-config bootstrap.local.toml
```

## See Also

- [deployment.md](./deployment.md)
- [commands.md](./commands.md)
- [configuration.md](./configuration.md)
- [services.md](./services.md)
- [openclaw-runtime.md](./openclaw-runtime.md)
- [gitops.md](./gitops.md)
- [networking.md](./networking.md)
