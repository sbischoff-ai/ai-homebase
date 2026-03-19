# Services reference

This document summarizes each service's role, default posture, toggle, and integration notes.

Canonical default posture in this document refers to umbrella defaults from `charts/platform-stack/values.yaml` before applying `values-k3d.yaml` or `values-k3s.yaml`.

## Composition overview

### Core plane

| Service | Role | Default expectation |
| --- | --- | --- |
| `openclaw` | General AI assistant UI/API | Enabled with private service access by default |
| `openshell` | Cluster-local sandbox gateway for OpenClaw and other workloads | Enabled by default as a reusable internal service |
| `openhands` | Agentic coding UI/API | Enabled by default; launches per-session Kubernetes runtime sandboxes inside the cluster |

### Default-on platform services

| Service | Toggle | Typical use |
| --- | --- | --- |
| `infisical` | `infisical.enabled` | Central secret-management service |
| `wg-easy` | `wgEasy.enabled` | WireGuard VPN management and private access |

### Optional personal-cloud services

| Service | Toggle | Typical use |
| --- | --- | --- |
| `nextcloud` | `nextcloud.enabled` | File sync/collaboration |
| `gitea` | `gitea.enabled` | Git hosting |
| `paperless-ngx` | `paperlessNgx.enabled` | Document ingestion/archive |

## Effective defaults (umbrella baseline)

| Service | Operator-facing toggle | Default in `charts/platform-stack/values.yaml` |
| --- | --- | --- |
| `openclaw` | `openclaw.enabled` | `true` |
| `openshell` | `openshell.enabled` | `true` |
| `openhands` | `openhands.enabled` | `true` |
| `nextcloud` | `nextcloud.enabled` | `true` |
| `gitea` | `gitea.enabled` | `false` |
| `paperless-ngx` | `paperlessNgx.enabled` | `false` |
| `infisical` | `infisical.enabled` | `true` |
| `wg-easy` | `wgEasy.enabled` | `true` |

## Core plane details

### OpenClaw

- General AI assistant service for user-facing chat/API use.
- Requires secret references for API/auth integrations.
- Mounts an in-memory writable `/tmp` and a persistent state directory.
- The chart renders `openclaw.json` from structured `openclaw.*` values.
- OpenClaw now defaults to OpenShell sandboxing by rendering `openclaw.agents.defaults.sandbox.mode=all`, `backend=openshell`, `scope=session`, and `workspaceAccess=rw`.
- The chart enables `openclaw.plugins.entries.openshell` by default and points `plugins.entries.openshell.config.gatewayEndpoint` at the cluster-local OpenShell service URL.
- The OpenClaw chart also exposes `plugins.entries.openshell.config.command`, so operators can keep the default `openshell` binary name or point at a custom CLI path in images that bundle the tool elsewhere.

### OpenHands

- Agentic coding service that provides a user-facing UI/API.
- Enabled by default in umbrella values.
- The chart explicitly renders `runtime = "kubernetes"` plus an upstream `[kubernetes]` config block so the web/API pod stays lightweight while runtime pods handle session execution.
- The service account is granted namespace-scoped RBAC to create and clean up runtime pods, services, ingresses, and PVCs in the configured runtime namespace.
- The Kubernetes runtime currently assumes OpenHands itself is running inside the cluster.
- Keep extra operator-defined volume mounts away from `/app` because that shadows the image entrypoint; the chart's own single-file `config.toml` subPath mount is the managed exception.

## Additional service details

### Nextcloud

- Stateful user data service with significant storage growth over time.
- Keep it on a dedicated hostname when exposing it through ingress.
- Backup/restore planning is mandatory before production use.

### Gitea

- Source control service with persistent repositories.
- Intended as an internal homelab service unless you deliberately expose it.
- Back up repositories and application state.

### Paperless-ngx

- Multi-volume document pipeline with separate `data`, `media`, `consume`, and `export` persistence paths.
- Default posture is internal/service-only unless ingress is intentionally enabled.

### Infisical

- In-cluster secret-management component using externalized DB/cache backends from shared services.

### wg-easy

- Provides VPN lifecycle UI and the WireGuard endpoint.
- For k3d, the overlay explicitly sets `wgEasy.securityContext.privileged: true` for local Docker-backed WireGuard compatibility.
- Node-level prerequisites remain required for WireGuard and iptables/NAT support.

## Secret contract model

Supported patterns include:

- `existingSecret`
- `envFromSecrets[]`
- `secretRefs[]`
- `secretEnv[]`

Use service-specific structured secret references where the chart provides them.

### OpenShell

- Reusable in-cluster execution gateway exposed via a stable `ClusterIP` Service named `openshell`.
- Reachable from any pod at `http://openshell.<namespace>.svc.cluster.local` and, within the same namespace, `http://openshell:80`.
- Not coupled to OpenClaw-specific templates; other workloads can reuse the same service endpoint and CLI-compatible gateway.
- The chart intentionally avoids Docker socket mounts and other host-Docker assumptions.
