# Deployment guide landing page

Use this page as the canonical starting point for deploying `ai-homebase` and finding the right environment-specific runbook.

## Choose your path

| Path | Best for | Start here |
| --- | --- | --- |
| k3d local | Local development, smoke tests, and quick iteration on a laptop/workstation. | [k3d deployment flow](./deployment-k3d.md) |
| AKS | Azure Kubernetes Service deployments with cloud ingress/TLS/storage planning. | [AKS deployment flow](./deployment-aks.md) |
| Generic Kubernetes / homelab | Existing cluster-first deployments (on-prem or homelab) using layered values and operator-managed ingress/secrets/storage. | Start with [AKS deployment flow](./deployment-aks.md) for the cluster workflow pattern, then adapt with [configuration layering](./configuration.md), [networking](./networking.md), and [storage](./storage.md). |

## Prerequisites summary

Before choosing a deployment path, confirm:

- Kubernetes + Helm tooling is installed and working:
  - [`kubectl`](https://kubernetes.io/docs/tasks/tools/)
  - [Helm 3](https://helm.sh/docs/intro/install/)
- Environment-specific tooling is available:
  - Local k3d path: [k3d](https://k3d.io/) and [Docker](https://docs.docker.com/get-docker/)
  - AKS path: Azure/AKS cluster access and ingress/TLS prerequisites in the AKS runbook
- You have planned values overlays and service toggles:
  - [Configuration and values layering](./configuration.md)
  - [Services reference and toggles](./services.md)

## Deployment runbooks

- Local cluster workflow: [docs/deployment-k3d.md](./deployment-k3d.md)
- AKS workflow: [docs/deployment-aks.md](./deployment-aks.md)

## Post-deploy: how to access services

After installation, use these docs to confirm service exposure and access patterns:

- [Networking and exposure model](./networking.md)
- [Services reference](./services.md)
- [k3d local ingress host access](./deployment-k3d.md#4-local-ingress-host-access-dnshosts)

## Troubleshooting jump links

- [k3d common failure modes and fixes](./deployment-k3d.md#5-common-failure-modes-and-fixes)
- [AKS pre-apply validation checks](./deployment-aks.md#6-validate-before-apply)
- [AKS post-deploy verification](./deployment-aks.md#8-post-deploy-verification)
- [Storage planning guidance](./storage.md)
- [Networking hardening and policy guidance](./networking.md#networkpolicy-guidance)
