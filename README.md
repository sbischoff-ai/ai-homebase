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

## Helm charts
The `charts/` directory includes:

- `openclaw/` — API/runtime service chart with optional ingress, persistence, autoscaling, disruption budget, and network policy controls.
- `openhands/` — orchestration service chart with optional workspace PVC, autoscaling, disruption budget, queue-ready environment values, and internal service defaults.
- `platform-stack/` — umbrella chart that composes `openclaw` and `openhands`, with platform-level placeholders for ingress, external secrets, observability, persistence, autoscaling, and worker isolation.

`charts/platform-stack/` also includes deployment profiles:

- `values.yaml` — safe defaults with feature toggles disabled by default where possible.
- `values-dev.yaml` — local/dev minimal profile (small resources, no optional platform integrations).
- `values-aks.yaml` — AKS-oriented example (ACR images, ingress assumptions, workload identity placeholders, Key Vault external-secrets placeholders).
- `values-prod.yaml` — production-shaped profile (higher scale/resources, stricter availability, hardened defaults).

All profiles keep `openclaw` externally accessible via ingress while maintaining an internal-only `ClusterIP` posture for `openhands`.

Each chart supports shared `global` values for common labels, pod annotations, image pull secrets, storage class defaults, host/domain conventions, and scheduling defaults.

## Prerequisites
Before using this repository, install:

- [Git](https://git-scm.com/)
- [Helm 3](https://helm.sh/docs/intro/install/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- Access to a Kubernetes cluster (local or remote)

## Quickstart
- Read documentation: [`docs/`](./docs/)
- Explore helper scripts: [`scripts/`](./scripts/)
- Review chart layout: [`charts/`](./charts/)
- Validate charts:
  - `helm lint charts/openclaw`
  - `helm lint charts/openhands`
  - `helm dependency update charts/platform-stack && helm lint charts/platform-stack`
  - `helm lint charts/platform-stack -f charts/platform-stack/values-dev.yaml`
  - `helm lint charts/platform-stack -f charts/platform-stack/values-aks.yaml`
  - `helm lint charts/platform-stack -f charts/platform-stack/values-prod.yaml`
