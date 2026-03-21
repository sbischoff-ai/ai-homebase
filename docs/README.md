# Documentation index

This is the single index for deeper `ai-homebase` documentation.

## Start with

- [`configuration.md`](./configuration.md): values layering, supported overlays, and where environment-specific decisions belong.
- [`services.md`](./services.md): service toggles, default posture, secret contracts, and integration notes.
- [`architecture.md`](./architecture.md): platform layout, supported targets, and trust boundaries.

## Deploy and operate

- [`deployment.md`](./deployment.md): quick decision page for choosing the right deployment workflow.
- [`deployment-k3d.md`](./deployment-k3d.md): local `k3d` bootstrap, manual install flow, service access, and teardown.
- [`k3d-troubleshooting.md`](./k3d-troubleshooting.md): Incus, cloud-init, networking internals, NixOS host setup notes, and deeper local troubleshooting.
- [`runbook-homelab.md`](./runbook-homelab.md): homelab `k3s` validation, install, upgrade, and post-install checks.
- [`commands.md`](./commands.md): canonical lint, render, install, CI, and helper commands.

## Platform reference

- [`networking.md`](./networking.md): ingress exposure, local hostname access, and runtime network boundaries.
- [`storage.md`](./storage.md): persistence sizing, storage-class choices, and backup expectations.
- [`charts.md`](./charts.md): chart-level structure and Helm packaging details.

## Examples

- [`../examples/README.md`](../examples/README.md): layer-on-top overlay patterns for supported targets, service profiles, and remote Docker customization.
