# Storage And Resource Strategy

This page summarizes storage-class selection, production sizing, and host headroom for the supported targets.

## Storage Resolution

PVC templates resolve storage class in this order:

1. service-specific storage class
2. `global.storageClass`
3. cluster default StorageClass

The `k3s` overlay sets `global.storageClass=local-path` and gives stateful services explicit `local-path` persistence.

## Rendered `k3s` Storage

| Service | Rendered `k3s` storage |
| --- | ---: |
| Nextcloud | `1Ti` |
| Qdrant | `150Gi` |
| Memgraph | `200Gi` |
| Gitea | `150Gi` |
| Registry | `100Gi` |
| Vaultwarden | `20Gi` |
| Paperless data | `50Gi` |
| Paperless media | `300Gi` |
| Paperless consume | `20Gi` |
| Paperless export | `20Gi` |
| Shared PostgreSQL | `150Gi` |
| Shared Redis | `30Gi` |
| OpenClaw shared hostPath budget | `100Gi` |

The rendered PVC requests total about `2.2TiB`; including the OpenClaw hostPath state budget, the planned state footprint is about `2.3TiB`. That is appropriate for the current roughly `3TiB` Hetzner A42U-class target while leaving useful free space for filesystem overhead, snapshots, logs, temporary image layers, and future services.

## Rendered `k3s` Resource Posture

The current `k3s` values request roughly `18Gi` steady Kubernetes memory before workload spikes and optional future apps. Limits remain below the `64Gi` host capacity while leaving room for:

- the 6 GiB Incus OpenClaw sandbox VM,
- node and k3s system overhead,
- image builds and registry pushes,
- backups, compaction, and service maintenance jobs,
- additional services deployed later through coder/GitOps.

Key steady requests in `values-k3s.yaml`:

| Workload | CPU request | Memory request | Memory limit |
| --- | ---: | ---: | ---: |
| OpenClaw gateway | `1` | `3Gi` | `8Gi` |
| Nextcloud | `1` | `3Gi` | `8Gi` |
| Qdrant | `750m` | `2Gi` | `6Gi` |
| Memgraph | `750m` | `2Gi` | `6Gi` |
| Gitea | `750m` | `1Gi` | `3Gi` |
| Paperless-ngx | `750m` | `1536Mi` | `6Gi` |
| Shared PostgreSQL | `1500m` | `3Gi` | `8Gi` |
| Shared Redis | `500m` | `1Gi` | `3Gi` |

This sizing is intentionally not packed to the machine's edge. The goal is a responsive single-node homelab with room for agent-driven work, not maximum theoretical utilization.

## Backup Expectations

Before production use, define and rehearse backups for:

- Nextcloud data and app config,
- Gitea repositories and database state,
- PostgreSQL and Redis,
- Qdrant and Memgraph,
- registry storage,
- OpenClaw shared state,
- bootstrap config and encrypted Secrets.

Snapshots are not a backup policy by themselves. Keep restore steps documented and test at least one restore path before treating the server as durable.
