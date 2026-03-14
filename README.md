# ai-homebase

## Project purpose
`ai-homebase` is an all-in-one Kubernetes platform starter for running an AI control plane plus optional personal-cloud services from a single Helm release.

The stack is intentionally opinionated around:

- A **core AI plane** (`openclaw` + `openhands`) that stays deployable on its own.
- A set of **optional services** (Nextcloud, Gitea, Paperless-ngx, Infisical, wg-easy) that can be enabled per environment.
- A **values-layering model** so dev, AKS, and production overlays remain predictable.

> **Intentional placeholders:** queue backends, external secret stores, observability destinations, and hardened network policy rules are left as operator-supplied values.

## Platform composition

### Core plane (always recommended)

- **OpenClaw**: external-facing API/UI control surface.
- **OpenHands**: internal execution runtime and worker orchestration.

### Optional supporting services

- **Nextcloud**: file collaboration and sync.
- **Gitea**: source control and lightweight CI adjacency.
- **Paperless-ngx**: document ingestion and archival workflows.
- **Infisical**: secret-management service (can be in-cluster or external).
- **wg-easy**: WireGuard management UI + VPN endpoint.

Enable only what you need in your environment overlay.

## Repository layout

- `charts/` — Helm charts and chart-related assets.
- `docs/` — architecture, deployment, configuration, service contracts, networking, and storage guidance.
- `scripts/` — helper scripts for linting, templating, and install workflows.
- `examples/` — sample values files and reference manifests.
- `.github/workflows/` — CI/CD workflows.

## Key docs

- [`docs/architecture.md`](./docs/architecture.md): core-plane boundaries + optional service roles.
- [`docs/services.md`](./docs/services.md): service-by-service toggle, dependency, and secret contract matrix.
- [`docs/configuration.md`](./docs/configuration.md): values hierarchy and layering guidance.
- [`docs/deployment-aks.md`](./docs/deployment-aks.md): AKS deployment flow with prerequisites and toggles.
- [`docs/storage.md`](./docs/storage.md): storage class strategy, PVC sizing, and backup gaps.
- [`docs/networking.md`](./docs/networking.md): ingress posture, internal/private patterns, and hardening checklist.

## Helm charts

The `charts/platform-stack` umbrella chart composes:

- `openclaw`
- `openhands`
- `nextcloud` (optional)
- `gitea` (optional)
- `paperless-ngx` (optional)
- `infisical` (optional)
- `wg-easy` (optional)

Profiles:

- `values.yaml` — baseline defaults.
- `values-dev.yaml` — minimal dev profile.
- `values-aks.yaml` — AKS-oriented profile with cloud integration placeholders.
- `values-prod.yaml` — production-shaped profile and stronger defaults.

## Prerequisites

- [Git](https://git-scm.com/)
- [Helm 3](https://helm.sh/docs/intro/install/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- Access to Kubernetes (AKS, homelab, or other distribution)

## Common commands

### Dependency install/update

```bash
helm dependency update charts/platform-stack
```

### Linting

```bash
helm lint charts/platform-stack
helm lint charts/platform-stack -f charts/platform-stack/values-dev.yaml
helm lint charts/platform-stack -f charts/platform-stack/values-aks.yaml
helm lint charts/platform-stack -f charts/platform-stack/values-prod.yaml
```

### Template rendering

```bash
helm template platform-stack charts/platform-stack
helm template platform-stack charts/platform-stack -f charts/platform-stack/values-dev.yaml
helm template platform-stack charts/platform-stack -f charts/platform-stack/values-aks.yaml
helm template platform-stack charts/platform-stack -f charts/platform-stack/values-prod.yaml
```

### Scripted helpers

```bash
./scripts/lint.sh --values-file charts/platform-stack/values-dev.yaml  # auto-discovers component charts
./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values-dev.yaml
./scripts/install-dev.sh --release-name platform-stack --namespace ai-homebase
./scripts/install-aks.sh --release-name platform-stack --namespace ai-homebase --kube-context <your-kube-context>
```

## Production-hardening gaps to close before go-live

- Replace placeholder hosts/domains and TLS issuers.
- Wire real secret stores (External Secrets + provider integration).
- Enforce deny-by-default `NetworkPolicy` per namespace/service.
- Validate backup/restore and volume-snapshot procedures.
- Use immutable image tags/digests and tighten pod security context.
- Confirm SLOs and alerting for both core plane and optional services.
