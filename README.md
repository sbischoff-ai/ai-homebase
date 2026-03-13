# ai-homebase

## Project purpose
`ai-homebase` is a starter repository for organizing Kubernetes and Helm-based home lab infrastructure in one place. It provides a clear layout for charts, documentation, automation scripts, and working examples so deployment and maintenance workflows can scale cleanly over time.

## Architecture overview
The repository is organized by responsibility:

- `charts/` — Helm charts and chart-related assets.
- `docs/` — project documentation, runbooks, and onboarding guides.
- `scripts/` — local helper scripts for setup, validation, and deployment tasks.
- `examples/` — sample values files and reference manifests.
- `.github/workflows/` — CI/CD workflow definitions.

See also:

- [`docs/architecture.md`](./docs/architecture.md) for control-plane vs execution-plane boundaries.
- [`docs/configuration.md`](./docs/configuration.md) for value layering and secrets strategy.
- [`docs/deployment-aks.md`](./docs/deployment-aks.md) for AKS-specific deployment notes.

## Helm charts
The `charts/` directory includes:

- `openclaw/` — API/runtime service chart with optional ingress, persistence, autoscaling, disruption budget, and network policy controls.
- `openhands/` — orchestration service chart with optional workspace PVC, autoscaling, disruption budget, queue-ready environment values, and internal service defaults.
- `platform-stack/` — umbrella chart that composes `openclaw` and `openhands`, with platform-level placeholders for ingress, external secrets, observability, persistence, autoscaling, and worker isolation.

`charts/platform-stack/` includes deployment profiles:

- `values.yaml` — safe defaults with feature toggles disabled by default where possible.
- `values-dev.yaml` — local/dev minimal profile (small resources, no optional platform integrations).
- `values-aks.yaml` — AKS-oriented example (ACR images, ingress assumptions, workload identity placeholders, Key Vault external-secrets placeholders).
- `values-prod.yaml` — production-shaped profile (higher scale/resources, stricter availability, hardened defaults).

All profiles keep `openclaw` externally accessible via ingress while maintaining an internal-only `ClusterIP` posture for `openhands`.

## Prerequisites
Before using this repository, install:

- [Git](https://git-scm.com/)
- [Helm 3](https://helm.sh/docs/intro/install/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- Access to a Kubernetes cluster (local or remote)

## Common commands

### Dependency install/update

```bash
helm dependency update charts/platform-stack
```

### Linting

```bash
helm lint charts/openclaw
helm lint charts/openhands
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

### Install/upgrade

```bash
helm upgrade --install platform-stack charts/platform-stack \
  -n ai-homebase \
  --create-namespace \
  -f charts/platform-stack/values-dev.yaml
```

## Environment profiles and usage

Choose a profile based on your target:

- **Dev/local**: `values-dev.yaml`
- **AKS**: `values-aks.yaml`
- **Prod-like baseline**: `values-prod.yaml`

Recommended pattern:

```bash
helm upgrade --install platform-stack charts/platform-stack \
  -n <namespace> \
  -f charts/platform-stack/values-<profile>.yaml \
  -f <your-environment-overrides>.yaml
```

This keeps shared profile intent in source control while environment-specific hostnames, image tags, and secret references live in overlays.

## Intended interaction model

- External clients interact with **`openclaw`** via ingress/API.
- `openclaw` handles control-plane concerns (validation/orchestration) and dispatches execution intents.
- **`openhands`** handles execution-plane concerns (job workers/workspaces) as an internal service.

This separation allows independent scaling and safer isolation of runtime workloads.

## Known placeholders

This starter repository intentionally leaves some integration values as placeholders:

- Container image sources/tags for real registries.
- Queue provider details and endpoints.
- External secret store references and remote keys.
- Workload identity client IDs.
- Observability/log shipping destinations.
- Worker isolation/runtime class settings.

Treat these as required environment integration tasks before production usage.

## Recommended next integration steps

1. **Images**
   - Build/publish `openclaw` and `openhands` images to your target registry.
   - Replace placeholder repositories with immutable release tags or digests.
2. **CI/CD**
   - Add pipeline stages for `helm dependency update`, `helm lint`, and `helm template` validation.
   - Add gated deploy stages that promote values overlays by environment.
3. **Secrets and identity**
   - Wire external secrets provider mappings and workload identity bindings.
4. **Observability and backups**
   - Finalize metrics/log destination integration and backup/snapshot policies.

## Quickstart

- Read documentation: [`docs/`](./docs/)
- Explore helper scripts: [`scripts/`](./scripts/)
- Review chart layout: [`charts/`](./charts/)
