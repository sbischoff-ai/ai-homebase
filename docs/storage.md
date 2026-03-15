# Storage strategy

This document covers storage-class selection, persistence toggles, and sizing for core + optional services.

## Storage resolution order

PVC templates resolve storage class in this order:

1. Service-specific class override.
2. `global.storageClass` fallback.
3. Cluster default StorageClass.

This allows one shared default plus targeted overrides where needed.

## Core plane storage

### OpenClaw

- Usually smaller durable state.
- By default, the chart persists OpenClaw state at `/home/node/.openclaw` (matching the container home for the upstream image user).
- Prioritize reliability and backup consistency.
- Keep recovery objectives aligned with API/control-plane requirements.

### OpenHands

- Workspace-heavy and potentially high churn.
- May require larger PVCs and different class/performance profile.
- Isolation by node pool/class can help contain noisy workloads.

## Optional service storage characteristics

- **Nextcloud**: fast growth in primary user data.
- **Gitea**: repositories, artifacts, and attachments accumulate over time.
- **Paperless-ngx**: data/media/consume/export volumes should be sized independently.
- **Infisical**: persistent state is externalized to shared backend releases; protect and back up `sharedPostgresql.primary.persistence.*` (critical encrypted secret data at rest) and `sharedRedis.master.persistence.*`.
- **wg-easy**: small but durable configuration/state volume.

## AKS-focused guidance

- Start with AKS CSI-backed classes, then tune per workload.
- Validate `allowVolumeExpansion` and snapshot support on all classes used.
- Avoid one-size-fits-all class choice for all services in production.

## Backup and restore expectations

Minimum production expectations:

- Snapshot/backup policy documented per persistent service.
- Restore rehearsals performed (not just backup job success).
- Retention aligned to service criticality and compliance needs.

## Intentional placeholders and hardening gaps

The repository includes backup annotation hooks and sizing defaults, but does **not** include:

- A complete backup controller installation.
- Environment-specific retention/SLA policy.
- Automated restore validation workflows.

Operators must close these gaps before production rollout.
