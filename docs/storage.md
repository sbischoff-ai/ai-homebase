# Storage strategy

This document covers storage-class selection, persistence toggles, and sizing for the supported k3d and k3s targets.

## Storage resolution order

PVC templates resolve storage class in this order:

1. Service-specific class override.
2. `global.storageClass` fallback.
3. Cluster default StorageClass.

## Core plane storage

### OpenClaw

- The productive `k3s` overlay now reserves `100Gi` for the shared OpenClaw state tree so agent workspaces, logs, session state, and sandbox metadata have room to grow.
- Persisted by default for `k3s`-style deployments.

## Optional service storage characteristics

- **Nextcloud**: heavy long-term data growth. The productive `k3s` overlay now reserves `1Ti` because this is the primary shared user storage surface.
- **Qdrant**: durable vector memory. The productive `k3s` overlay reserves `150Gi`.
- **Memgraph**: durable graph memory. The productive `k3s` overlay reserves `200Gi`.
- **Gitea**: repositories and attachments accumulate over time. The productive `k3s` overlay reserves `150Gi`.
- **Registry**: canonical image storage for OpenClaw sandboxes and future coder-built applications. The productive `k3s` overlay reserves `100Gi`.
- **Paperless-ngx**: size `data`, `media`, `consume`, and `export` independently. The productive `k3s` overlay reserves `50Gi` for metadata and `300Gi` for media.
- **Shared PostgreSQL**: the productive `k3s` overlay reserves `150Gi` for the consolidated relational data tier.
- **Shared Redis**: the productive `k3s` overlay keeps a persistent `30Gi` volume for the services in this stack that expect durable Redis state.

## Backup and restore expectations

Minimum production expectations:

- documented snapshot/backup policy,
- restore rehearsals,
- retention aligned to service criticality.
