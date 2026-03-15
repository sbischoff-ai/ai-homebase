# ai-homebase

## What is this repo?
`ai-homebase` is a Kubernetes + Helm starter for running a core AI platform with optional homelab services from a single umbrella chart. Canonical defaults are defined in `charts/platform-stack/values.yaml`: `openclaw`, `openhands`, `nextcloud`, `infisical`, and `wgEasy` are enabled, while `gitea` and `paperlessNgx` are opt-in.

The repository is designed around predictable values layering and environment overlays so you can keep local, cloud, and production-style deployments aligned while still choosing different service toggles per environment. It is intentionally opinionated about composition, but leaves environment-specific details (domains, secrets, storage classes, and hardening choices) to operator-managed overlays.

Use this repo when you want one place to manage chart composition, service enablement, and deployment workflows for both local iteration and real cluster targets.

## Quick start: deploy and use

Start with the canonical deployment landing page:

- [How do I deploy and use it? (`docs/deployment.md`)](./docs/deployment.md)

From there, choose the environment-specific flow for k3d local, AKS, or generic Kubernetes/homelab deployments.

Essential commands:

```bash
./scripts/k3d-up.sh
helm dependency update charts/platform-stack
make lint
make render > /tmp/platform-stack-dev.yaml
./scripts/test-local-k3d.sh
./scripts/install-dev.sh --values-file charts/platform-stack/values-dev.yaml
```

`./scripts/install-dev.sh` assumes your kube context is already reachable and correctly selected.

For complete command coverage (Make targets, lint/render variants, CI-equivalent checks, and helper scripts), see [`docs/commands.md`](./docs/commands.md).

For day-2 operations on generic cluster/homelab installs, use the [Homelab operations runbook (`docs/runbook-homelab.md`)](./docs/runbook-homelab.md).

For a VPN-first homelab posture with public Nextcloud only, layer `charts/platform-stack/values-homelab-public-nextcloud.yaml` after `values-dev.yaml`. Keep Nextcloud on a dedicated host (`cloud.<domain>`) rather than a subpath for mobile/WebDAV/public-link compatibility.
Paperless defaults to service-only (`paperlessNgx.ingress.enabled: false`) across baseline and shipped overlays; only enable ingress in environment overlays when you intentionally need internal ingress routing.

## Documentation map

- [Full docs taxonomy (`docs/README.md`)](./docs/README.md)

## Where to go next
- Configuration layering and toggle model: [`docs/configuration.md`](./docs/configuration.md)
- Service contracts, toggles, and secret wiring: [`docs/services.md`](./docs/services.md)
- Ingress and exposure patterns: [`docs/networking.md`](./docs/networking.md)
- Persistence and storage planning: [`docs/storage.md`](./docs/storage.md)
- Architecture and component boundaries: [`docs/architecture.md`](./docs/architecture.md)
