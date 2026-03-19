# Services reference

This document summarizes each service's role, default posture, toggle, and integration notes.

Canonical default posture in this document refers to umbrella defaults from `charts/platform-stack/values.yaml` before applying `values-k3d.yaml` or `values-k3s.yaml`.

## Composition overview

### Core plane

| Service | Role | Default expectation |
| --- | --- | --- |
| `openclaw` | General AI assistant UI/API | Enabled with private service access by default |
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
- OpenClaw now defaults to Docker sandboxing with `mode=non-main`, `backend=docker`, and `scope=agent`, plus explicit `docker.*` and `browser.*` sandbox image/runtime settings rendered into `openclaw.json`.
- The browser sandbox config now exposes `openclaw.agents.defaults.sandbox.browser.cdpSourceRange` so operators can match the CIDR that reaches the remote browser container's CDP port.
- `openclaw.remoteDocker.*` exports `DOCKER_HOST` and `HOME`, then mounts SSH credentials for Docker's `ssh://` transport so OpenClaw launches Docker/browser sandboxes on the standard remote daemon without changing the OpenClaw backend away from `docker`.
- The supported posture is an external Incus VM (`openclaw-sandbox`) as a single-purpose remote Docker appliance, while the VM remains outside Helm; chart values control only how the OpenClaw pod reaches it.

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
