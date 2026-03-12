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

