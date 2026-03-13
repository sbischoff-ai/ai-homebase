# Storage guidance and sizing rationale

This repository supports both cloud-managed and self-managed Kubernetes storage with the same Helm values interface.

## StorageClass behavior

All service PVC templates in this repo resolve `storageClassName` in this order:

1. Service-level override (`<service>.persistence.storageClass` or `paperlessNgx.persistence.<volume>.storageClass`)
2. Global fallback (`global.storageClass`)
3. Cluster default StorageClass (when both are empty)

This lets operators set a single platform default while still overriding specific workloads.

## AKS CSI vs bare-metal

### AKS CSI (`managed-csi`, `premium-rwo`, etc.)

- Backed by Azure managed disks and CSI provisioners.
- Good default for `ReadWriteOnce` application PVCs.
- Performance tier is selected by storage class (for example standard vs premium).
- Expansion and snapshots are typically available out-of-the-box depending on class policy.

### Bare-metal / homelab classes (`local-path`, `longhorn`, `rook-ceph`, NFS-backed classes)

- Characteristics vary by implementation:
  - `local-path`: simple and fast, but node-affine and less resilient.
  - Longhorn/Rook Ceph: replicated/distributed, more resilient, higher overhead.
  - NFS classes: shared access patterns, but throughput/latency depend on backend.
- Snapshot/backup behavior is driver-dependent and should be validated before production.

## Sizing defaults rationale

The default storage values in `platform-stack` are intentionally pragmatic:

- **Nextcloud**: large primary data volume, because user file content grows quickly.
- **Gitea**: substantial repository volume for git history, artifacts, and attachments.
- **Paperless-ngx**: split volumes for `data`, `media`, `consume`, and `export` so ingestion and archive growth can be tuned independently.
- **Infisical / wg-easy**: modest baseline storage with room for metadata, state, and config growth.

Treat these as starter baselines. Real sizing should be adjusted with observed growth, retention policies, and backup windows.

## Backup annotation placeholders

PVC and workload templates expose `backup.annotations` placeholders so backup systems (for example Velero) can be wired without forking templates.

Recommended pattern:

- Set service-specific `backup.annotations` values in environment overlays.
- Optionally add per-PVC `persistence.annotations` for claim-specific policy.
- Keep values empty unless your backup controller requires explicit selectors.
