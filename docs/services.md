# Services reference

This document summarizes each service's role, default posture, toggle, and integration notes.

Canonical default posture in this document refers to umbrella defaults from `charts/platform-stack/values.yaml` before applying `values-k3d.yaml` or `values-k3s.yaml`.

## Composition overview

### Core plane

| Service | Role | Default expectation |
| --- | --- | --- |
| `openclaw` | General AI assistant UI/API | Enabled with ingress by default |
| `openhands` | Agentic coding UI/API | Enabled by default with ingress; launches per-session Kubernetes runtime sandboxes inside the cluster |

### Default-on platform services

| Service | Toggle | Typical use |
| --- | --- | --- |
| `infisical` | `infisical.enabled` | Central secret-management service |

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

## Core plane details

### OpenClaw

- General AI assistant service for user-facing chat/API use.
- Requires secret references for API/auth integrations.
- Mounts an in-memory writable `/tmp` and a persistent state directory.
- The chart renders `openclaw.json` from structured `openclaw.*` values.
- OpenClaw now defaults to Docker sandboxing with `mode=non-main` and `scope=agent`, plus explicit `docker.*` and `browser.*` sandbox image/runtime settings rendered into `openclaw.json`.
- The browser sandbox config now exposes `openclaw.agents.defaults.sandbox.browser.cdpSourceRange` so operators can match the CIDR that reaches the remote browser container's CDP port.
- `openclaw.remoteDocker.*` exports `DOCKER_HOST` and `HOME`, then mounts SSH credentials for Docker's `ssh://` transport so OpenClaw launches Docker/browser sandboxes on the standard remote daemon without changing the OpenClaw backend away from `docker`. The Secret named by `remoteDocker.ssh.secretName` must contain non-empty `id_ed25519` and `known_hosts` keys because the init container validates and copies only those files before the main container starts.
- The `remote-docker-ssh-permissions` init container is expected to run as UID/GID `0` with `allowPrivilegeEscalation: false`, a read-only root filesystem, and only the `CHOWN` capability retained while it first locks `/ssh-target` down to OpenSSH-safe modes and then hands the copied SSH files to the main container, which still runs as non-root UID/GID `1000`.
- The copied SSH material is intentionally normalized to OpenSSH-safe permissions before the main container starts: the SSH directory is `0700`, `id_ed25519` is `0600`, and `known_hosts` remains readable at `0644`.
- If OpenClaw is stuck in `Init:CrashLoopBackOff`, inspect the `remote-docker-ssh-permissions` init-container logs first; missing or empty `id_ed25519` / `known_hosts` entries in `remoteDocker.ssh.secretName`, any failure while locking down `/ssh-target` modes, or any failure to hand the prepared directory to UID/GID `1000` are supported failure modes with explicit stderr output.
- The supported posture is an external Incus VM (`openclaw-sandbox`) as a single-purpose remote Docker appliance, while the VM remains outside Helm; chart values control only how the OpenClaw pod reaches it.

### OpenHands

- Agentic coding service that provides a user-facing UI/API.
- Enabled by default in umbrella values.
- The chart explicitly renders `runtime = "kubernetes"` plus an upstream `[kubernetes]` config block so the web/API pod stays lightweight while runtime pods handle session execution.
- The service account is granted namespace-scoped RBAC to create and clean up runtime pods, services, ingresses, and PVCs in the configured runtime namespace.
- The Kubernetes runtime currently assumes OpenHands itself is running inside the cluster.
- Preferred operator-facing storage keys live under `openhands.persistence.*` (`enabled`, `existingClaim`, `size`, `storageClass`, `mountPath`, and `annotations`).
- The umbrella chart still carries `openhands.workspace.*` defaults as a temporary compatibility layer for older overlays, but `workspace.*` is deprecated and should not be used in new overlays.
- The shipped `values-k3d.yaml` overlay keeps `openhands.persistence.enabled=false`, while `values-k3s.yaml` enables `openhands.persistence` with a persistent PVC and explicit size/storage class defaults.
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

## External VPN gateway note

- Deploy `wg-easy` separately on the server that hosts this stack, outside the Kubernetes cluster.
- That external `wg-easy` instance is expected to provide the VPN gateway to the internet for the homelab environment.

## Secret contract model

Supported patterns include:

- `existingSecret`
- `envFromSecrets[]`
- `secretRefs[]`
- `secretEnv[]`

Use service-specific structured secret references where the chart provides them.
