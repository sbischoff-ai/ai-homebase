# ai-homebase

## Project purpose
`ai-homebase` is an all-in-one Kubernetes platform starter for running a general AI assistant (OpenClaw), an agentic coding platform (OpenHands), and optional personal-cloud services from a single Helm release.

The stack is intentionally opinionated around:

- A **core AI plane** (`openclaw` + `openhands`) that stays deployable on its own.
- A set of **optional services** (Nextcloud, Gitea, Paperless-ngx, Infisical, wg-easy) that can be enabled per environment.
- A **values-layering model** so dev, AKS, and production overlays remain predictable.

> **Intentional placeholders:** queue backends, external secret stores, observability destinations, and hardened network policy rules are left as operator-supplied values.

## Platform composition

### Core plane (always recommended)

- **OpenClaw**: general AI assistant with user-facing API/UI.
- **OpenHands**: agentic coding platform with user-facing UI/API.

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
- [`docs/deployment-k3d.md`](./docs/deployment-k3d.md): local k3d bootstrap, smoke checks, ingress host access, and troubleshooting.
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

- `values.yaml` — baseline defaults (including OpenHands service-only exposure: ClusterIP on port 3000, ingress disabled).
- `values-dev.yaml` — minimal dev profile.
- `values-k3d.yaml` — k3d local-smoke overlay (layer on top of `values-dev.yaml`).
- `values-aks.yaml` — AKS-oriented profile with cloud integration placeholders.
- `values-prod.yaml` — production-shaped profile and stronger defaults.

## Prerequisites

- [Git](https://git-scm.com/)
- [Helm 3](https://helm.sh/docs/intro/install/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Docker](https://docs.docker.com/get-docker/) (required by k3d)
- [k3d](https://k3d.io/) (for local cluster lifecycle scripts)
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
helm lint charts/platform-stack -f charts/platform-stack/values-dev.yaml -f charts/platform-stack/values-k3d.yaml
helm lint charts/platform-stack -f charts/platform-stack/values-aks.yaml
helm lint charts/platform-stack -f charts/platform-stack/values-prod.yaml
```

### Template rendering

```bash
helm template platform-stack charts/platform-stack
helm template platform-stack charts/platform-stack -f charts/platform-stack/values-dev.yaml
helm template platform-stack charts/platform-stack -f charts/platform-stack/values-dev.yaml -f charts/platform-stack/values-k3d.yaml
helm template platform-stack charts/platform-stack -f charts/platform-stack/values-aks.yaml
helm template platform-stack charts/platform-stack -f charts/platform-stack/values-prod.yaml
```

### Local validation (base + k3d)

```bash
./scripts/lint.sh --values-file charts/platform-stack/values-dev.yaml
./scripts/lint.sh --values-file charts/platform-stack/values-dev.yaml --values-file charts/platform-stack/values-k3d.yaml
./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values-dev.yaml > /tmp/platform-stack-dev.yaml
./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values-dev.yaml --values-file charts/platform-stack/values-k3d.yaml > /tmp/platform-stack-k3d.yaml
```

### Scripted helpers

```bash
./scripts/lint.sh --values-file charts/platform-stack/values-dev.yaml  # base/dev overlay
./scripts/lint.sh --values-file charts/platform-stack/values-dev.yaml --values-file charts/platform-stack/values-k3d.yaml  # k3d profile
./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values-dev.yaml
./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values-dev.yaml --values-file charts/platform-stack/values-k3d.yaml
./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values-dev.yaml --values-file charts/platform-stack/values-k3d.yaml --values-file examples/k3d.values.override.yaml
./scripts/install-dev.sh --release-name platform-stack --namespace ai-homebase
./scripts/install-aks.sh --release-name platform-stack --namespace ai-homebase --kube-context <your-kube-context>
./scripts/k3d-up.sh --cluster-name ai-homebase-dev
./scripts/test-local-k3d.sh --release-name platform-stack --namespace ai-homebase
./scripts/k3d-down.sh --cluster-name ai-homebase-dev
```

## Infisical secret contract

For this repository, **in-cluster mode is the default** for Infisical (`charts/infisical/values.yaml` keeps `postgresql.enabled=true` and `redis.enabled=true`).

Stateful retention for in-cluster Infisical lives on dependency PVCs, not an app-level Infisical PVC:

- `postgresql.primary.persistence.size`
- `postgresql.primary.persistence.storageClass`
- `redis.master.persistence.size`
- `redis.master.persistence.storageClass`

The PostgreSQL PVC is the critical data volume because it holds Infisical's encrypted secret data at rest. Treat it as a protected/backup-required volume.

Set `infisical.kubeSecretRef` to a Kubernetes Secret that includes:

- `AUTH_SECRET`
- `ENCRYPTION_KEY`
- `SITE_URL`

`SITE_URL` must exactly match the internal URL users on VPN/private network use to access the Infisical UI (same scheme + hostname, and port if non-default).

These keys are always wired into the Infisical container in chart templates for in-cluster mode.

### Auto-bootstrap credentials

`infisical.autoBootstrap.*` values are exposed by the Infisical chart and can be configured from `platform-stack` via `infisical.infisical.autoBootstrap.*`:

- `enabled`
- `organization`
- `credentialSecret.name`
- `secretDestination.name`
- `secretDestination.namespace`

When `infisical.autoBootstrap.enabled=true`, `credentialSecret.name` must reference a Kubernetes Secret containing:

- `INFISICAL_ADMIN_EMAIL`
- `INFISICAL_ADMIN_PASSWORD`

When auto-bootstrap is disabled, Infisical falls back to default first-run behavior where the first signup becomes the admin user.

For internal-only ingress posture, prefer private/VPN hostnames and an internal ingress class. Example:

```yaml
ingress:
  enabled: true
  ingressClassName: internal-nginx
  hostName: infisical.vpn.homebase.internal
  annotations:
    kubernetes.io/ingress.class: internal-nginx
    nginx.ingress.kubernetes.io/whitelist-source-range: 10.0.0.0/8,192.168.0.0/16
  tls:
    - secretName: infisical-vpn-tls
      hosts:
        - infisical.vpn.homebase.internal
```

### External mode (optional / future path)

If you disable in-cluster PostgreSQL and/or Redis and point Infisical to external services, the same `infisical.kubeSecretRef` Secret can additionally provide:

- `DB_CONNECTION_URI`
- `REDIS_URL`

These keys are optional and only used when in-cluster dependencies are disabled.

## Production-hardening gaps to close before go-live

- Replace placeholder hosts/domains and TLS issuers.
- Wire real secret stores (External Secrets + provider integration).
- Enforce deny-by-default `NetworkPolicy` per namespace/service.
- Validate backup/restore and volume-snapshot procedures.
- Use immutable image tags/digests and tighten pod security context.
- Confirm SLOs and alerting for both core plane and optional services.
