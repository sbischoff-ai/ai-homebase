# Documentation map

Use this page as the full documentation map for `ai-homebase`, organized by operator goal.

## Start here

- [`docs/deployment.md`](./deployment.md): Read this first when you need the deployment entrypoint and want help choosing the right install path.
- [`docs/configuration.md`](./configuration.md): Read this early when you need to understand values layering, overlays, and where environment-specific settings should live.
- [`docs/architecture.md`](./architecture.md): Read this when you want a quick picture of the platform layout, supported targets, and trust boundaries before making changes.

## Deploy

- [`docs/deployment.md`](./deployment.md): Read this when you need the deployment entrypoint for choosing between local `k3d`, homelab `k3s`, install commands, and prerequisites.
- [`docs/deployment-k3d.md`](./deployment-k3d.md): Read this when you want the concise local `k3d` bootstrap, manual install flow, service access, and teardown path.
- [`docs/k3d-troubleshooting.md`](./k3d-troubleshooting.md): Read this when you need Incus, cloud-init, networking internals, NixOS host setup notes, or deeper troubleshooting for the local `k3d` path.
- [`docs/runbook-homelab.md`](./runbook-homelab.md): Read this when you are deploying to homelab `k3s` and need the validation, install, upgrade, and post-install workflow.

## Configure

- [`docs/configuration.md`](./configuration.md): Read this when you are deciding where a value should live and how overlays should be layered.
- [`docs/services.md`](./services.md): Read this when you need service toggles, default posture, secret contracts, or integration notes for a specific component.
- [`docs/networking.md`](./networking.md): Read this when you are planning ingress exposure, local hostname access, or runtime network boundaries.
- [`docs/storage.md`](./storage.md): Read this when you are sizing persistence, choosing storage classes, or planning backup expectations.

## Operate

- [`docs/runbook-homelab.md`](./runbook-homelab.md): Read this after install when you need the k3s homelab validation, upgrade, and health-check workflow.
- [`docs/commands.md`](./commands.md): Read this when you want the canonical lint, render, install, CI, and helper commands in one place during day-2 operations.

## Examples

- [`examples/README.md`](../examples/README.md): Read this when you need real layer-on-top overlay patterns for supported targets, service profiles, and remote Docker customization.

## Reference

- [`docs/architecture.md`](./architecture.md): Read this when you need the platform layout, supported targets, and trust-boundary overview as a reference.
- [`docs/charts.md`](./charts.md): Read this when you need chart-level structure and packaging details for the repository's Helm components.
- [`docs/services.md`](./services.md): Read this when you need a service-by-service reference for defaults, toggles, and operator-facing behavior.
- [`docs/commands.md`](./commands.md): Read this when you need a quick command lookup without revisiting the longer workflow guides.
