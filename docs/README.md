# Documentation

Use this index as the map for the repository after the top-level [README.md](../README.md).

## Entry Points

- [`deployment.md`](./deployment.md): choose `k3d` or `k3s`
- [`deployment-k3d.md`](./deployment-k3d.md): full local bootstrap path
- [`runbook-homelab.md`](./runbook-homelab.md): full homelab `k3s` path

## Core Concepts

- [`configuration.md`](./configuration.md): values layering, bootstrap config, and environment-specific inputs
- [`services.md`](./services.md): service toggles, secret contracts, and runtime expectations
- [`architecture.md`](./architecture.md): platform structure and target model

## Deep Dives

- [`security.md`](./security.md): secrets, trust boundaries, internal CA, Vaultwarden admin access, and remote Docker SSH posture
- [`networking.md`](./networking.md): ingress model, hostname strategy, TLS posture, and local host access
- [`gitops.md`](./gitops.md): second-stage Argo CD bootstrap, Gitea repo handoff, and GitOps operating model
- [`storage.md`](./storage.md): persistence and backup expectations
- [`charts.md`](./charts.md): chart composition and packaging notes

## Operations

- [`commands.md`](./commands.md): canonical commands
- [`k3d-troubleshooting.md`](./k3d-troubleshooting.md): local troubleshooting and implementation details
- [`../examples/README.md`](../examples/README.md): example overlays and layer-on-top patterns
