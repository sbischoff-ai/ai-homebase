# Storage strategy

This document covers storage-class selection, persistence toggles, and sizing for the supported k3d and k3s targets.

## Storage resolution order

PVC templates resolve storage class in this order:

1. Service-specific class override.
2. `global.storageClass` fallback.
3. Cluster default StorageClass.

## Core plane storage

### OpenClaw

- Smaller durable state.
- Persisted by default for k3s-style deployments.

### OpenHands

- Persistence-heavy and high churn.
- Use `openhands.persistence.*` for operator-facing storage overrides such as `enabled`, `size`, and `storageClass`.
- The k3s overlay enables persistent storage; the k3d overlay keeps it ephemeral.
- `openhands.workspace.*` remains only as a deprecated compatibility fallback for older overlays and should not be used in new values files.

## Optional service storage characteristics

- **Nextcloud**: heavy long-term data growth.
- **Gitea**: repositories and attachments accumulate over time.
- **Paperless-ngx**: size `data`, `media`, `consume`, and `export` independently.
- **Infisical**: protect the shared PostgreSQL and Redis backends.

## Backup and restore expectations

Minimum production expectations:

- documented snapshot/backup policy,
- restore rehearsals,
- retention aligned to service criticality.
