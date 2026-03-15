# ai-homebase

## What is this repo?
`ai-homebase` is a Kubernetes + Helm starter for running a core AI platform with optional homelab services from a single umbrella chart. The default shape is a core plane (`openclaw` and `openhands`) plus opt-in services such as Nextcloud, Gitea, Paperless-ngx, Infisical, and wg-easy.

The repository is designed around predictable values layering and environment overlays so you can keep local, cloud, and production-style deployments aligned while still choosing different service toggles per environment. It is intentionally opinionated about composition, but leaves environment-specific details (domains, secrets, storage classes, and hardening choices) to operator-managed overlays.

Use this repo when you want one place to manage chart composition, service enablement, and deployment workflows for both local iteration and real cluster targets.

## Quick start: deploy and use

### Local path (k3d)
For a local development cluster and smoke workflow, follow the k3d deployment guide:

- [Deploy on k3d (`docs/deployment-k3d.md`)](./docs/deployment-k3d.md)

### Cloud/homelab path (AKS or cluster-first)
For AKS-oriented deployment steps (and patterns you can adapt to homelab clusters), use:

- [Deploy on AKS (`docs/deployment-aks.md`)](./docs/deployment-aks.md)

## Where to go next
- Configuration layering and toggle model: [`docs/configuration.md`](./docs/configuration.md)
- Service contracts, toggles, and secret wiring: [`docs/services.md`](./docs/services.md)
- Ingress and exposure patterns: [`docs/networking.md`](./docs/networking.md)
- Persistence and storage planning: [`docs/storage.md`](./docs/storage.md)
- Architecture and component boundaries: [`docs/architecture.md`](./docs/architecture.md)
