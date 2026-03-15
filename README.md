# ai-homebase

## What is this repo?
`ai-homebase` is a Kubernetes + Helm starter for running a core AI platform with optional homelab services from a single umbrella chart. The default shape is a core plane (`openclaw` and `openhands`) plus default-on platform services (`infisical` and `wg-easy`) and opt-in services such as Nextcloud, Gitea, and Paperless-ngx.

The repository is designed around predictable values layering and environment overlays so you can keep local, cloud, and production-style deployments aligned while still choosing different service toggles per environment. It is intentionally opinionated about composition, but leaves environment-specific details (domains, secrets, storage classes, and hardening choices) to operator-managed overlays.

Use this repo when you want one place to manage chart composition, service enablement, and deployment workflows for both local iteration and real cluster targets.

## Quick start: deploy and use

Start with the canonical deployment landing page:

- [How do I deploy and use it? (`docs/deployment.md`)](./docs/deployment.md)

From there, choose the environment-specific flow for k3d local, AKS, or generic Kubernetes/homelab deployments.

Essential commands:

```bash
helm dependency update charts/platform-stack
make lint
make render > /tmp/platform-stack-dev.yaml
./scripts/install-dev.sh --values-file charts/platform-stack/values-dev.yaml
./scripts/k3d-up.sh
```

For complete command coverage (Make targets, lint/render variants, CI-equivalent checks, and helper scripts), see [`docs/commands.md`](./docs/commands.md).

For day-2 operations on generic cluster/homelab installs, use the [Homelab operations runbook (`docs/runbook-homelab.md`)](./docs/runbook-homelab.md).

## Documentation map

- [Full docs taxonomy (`docs/README.md`)](./docs/README.md)

## Where to go next
- Configuration layering and toggle model: [`docs/configuration.md`](./docs/configuration.md)
- Service contracts, toggles, and secret wiring: [`docs/services.md`](./docs/services.md)
- Ingress and exposure patterns: [`docs/networking.md`](./docs/networking.md)
- Persistence and storage planning: [`docs/storage.md`](./docs/storage.md)
- Architecture and component boundaries: [`docs/architecture.md`](./docs/architecture.md)
