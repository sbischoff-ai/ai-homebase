# Services reference

This document describes umbrella defaults first, then calls out how the supported `k3d` and `k3s` overlays change that posture. Read overlay-specific behavior here alongside [`docs/configuration.md`](./configuration.md) so the values layering order stays clear.

Canonical baseline posture in this document refers to `charts/platform-stack/values.yaml` before applying `charts/platform-stack/values-k3d.yaml` or `charts/platform-stack/values-k3s.yaml`.

## Service matrix

| Service | Toggle | Baseline default | k3d posture | k3s posture | Ingress default | Persistence default | Secret requirements |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `openclaw` | `openclaw.enabled` | Enabled | Enabled for local smoke tests | Enabled for the productive homelab | Enabled in baseline; both overlays keep ingress on and switch to the `nginx` ingress class | Baseline PVC enabled (`10Gi`); `k3d` disables persistence; `k3s` keeps persistence on and grows it to `50Gi` on `local-path` | Requires `openclaw.existingSecret`; baseline expects `OPENCLAW_GATEWAY_TOKEN`, and `k3d` also maps `OPENAI_API_KEY`; remote Docker SSH Secret `openclaw-remote-docker-ssh` must provide `id_ed25519` and `known_hosts` |
| `openhands` | `openhands.enabled` | Enabled | Enabled for local smoke tests | Enabled for the productive homelab | Enabled in baseline; both overlays keep ingress on and switch to the `nginx` ingress class | Baseline keeps the deprecated `workspace.*` path off; `k3d` keeps `openhands.persistence.enabled=false`; `k3s` enables a PVC (`100Gi`, `local-path`) for operator-facing persistence | No baseline Secret is required by the umbrella values; add environment-specific Secret references through overlays when integrating external providers |
| `nextcloud` | `nextcloud.enabled` | Enabled | Disabled to keep local smoke tests light | Enabled for the productive homelab | Enabled in baseline; `k3s` keeps ingress on and moves it to the `nginx` ingress class | Baseline PVC enabled (`250Gi`); `k3d` disables the service and persistence; `k3s` keeps persistence on with `250Gi` on `local-path` | `existingSecret` is optional in baseline and empty by default; provide one in overlays when operator-managed app secrets are needed |
| `gitea` | `gitea.enabled` | Disabled | Disabled | Enabled for the productive homelab | Subchart ingress is enabled when the service is enabled; baseline uses `internal-nginx`, and `k3s` switches it to `nginx` | Subchart PVC is enabled by default (`120Gi`); it is inactive until `gitea.enabled=true`, which only happens in `k3s` among supported overlays | `gitea.gitea.admin.existingSecret` is empty by default and should be set in overlays; database, session, cache, queue, and lock credentials are expected through environment-backed Secret values |
| `paperless-ngx` | `paperlessNgx.enabled` | Disabled | Disabled | Enabled for the productive homelab | Baseline ingress is enabled when the service is enabled; `k3s` keeps ingress on and switches it to the `nginx` ingress class | Baseline enables all four PVCs (`data`, `media`, `consume`, `export`); `k3d` disables the service and each PVC; `k3s` enables the service with all four PVCs on `local-path` | `existingSecret` is optional in baseline and empty by default; provide Secret references in overlays for mail, OCR, or other runtime integrations |
| `infisical` | `infisical.enabled` | Enabled | Enabled for local smoke tests | Enabled for the productive homelab | Enabled in baseline; both overlays keep ingress on and switch to the `nginx` ingress class | No Infisical-managed PVCs are enabled here because the chart is wired to shared PostgreSQL and Redis services instead of bundled stateful dependencies | Baseline expects `infisical.infisical.kubeSecretRef=infisical-secrets`; `autoBootstrap.credentialSecret.name` defaults to `infisical-bootstrap-credentials` when bootstrap automation is turned on |

## Per-service notes

### OpenClaw

- General AI assistant service for user-facing chat/API use.
- The chart renders `openclaw.json` from structured `openclaw.*` values.
- OpenClaw defaults to Docker sandboxing with `mode=non-main` and `scope=agent`, plus explicit `docker.*` and `browser.*` sandbox image/runtime settings rendered into `openclaw.json`; the chart intentionally omits `backend` because the shipped OpenClaw image already defaults it to Docker.
- The browser sandbox config exposes `openclaw.agents.defaults.sandbox.browser.cdpSourceRange` so operators can match the CIDR that reaches the remote browser container's CDP port.
- `openclaw.remoteDocker.*` exports `DOCKER_HOST` and `HOME`, then mounts SSH credentials for Docker's `ssh://` transport so OpenClaw launches Docker/browser sandboxes on the standard remote daemon without changing the OpenClaw backend away from `docker`.
- The Secret named by `openclaw.remoteDocker.ssh.secretName` must contain non-empty `id_ed25519` and `known_hosts` keys because the init container validates and copies only those files before the main container starts.
- The `remote-docker-ssh-permissions` init container is expected to run as UID/GID `0` with `allowPrivilegeEscalation: false`, a read-only root filesystem, and only the `CHOWN` capability retained while it first locks `/ssh-target` down to OpenSSH-safe modes and then hands the copied SSH files to the main container, which still runs as non-root UID/GID `1000`.
- The copied SSH material is intentionally normalized to OpenSSH-safe permissions before the main container starts: the SSH directory is `0700`, `id_ed25519` is `0600`, and `known_hosts` remains readable at `0644`.
- If OpenClaw is stuck in `Init:CrashLoopBackOff`, inspect the `remote-docker-ssh-permissions` init-container logs first; missing or empty `id_ed25519` / `known_hosts` entries in `remoteDocker.ssh.secretName`, any failure while locking down `/ssh-target` modes, or any failure to hand the prepared directory to UID/GID `1000` are supported failure modes with explicit stderr output.
- The supported posture is an external Incus VM (`openclaw-sandbox`) as a single-purpose remote Docker appliance, while the VM remains outside Helm; chart values control only how the OpenClaw pod reaches it.

### OpenHands

- Agentic coding service that provides a user-facing UI/API.
- The chart explicitly renders `runtime = "kubernetes"` plus an upstream `[kubernetes]` config block so the web/API pod stays lightweight while runtime pods handle session execution.
- The service account is granted namespace-scoped RBAC to create and clean up runtime pods, services, ingresses, and PVCs in the configured runtime namespace.
- The Kubernetes runtime currently assumes OpenHands itself is running inside the cluster.
- Preferred operator-facing storage keys live under `openhands.persistence.*` (`enabled`, `existingClaim`, `size`, `storageClass`, `mountPath`, and `annotations`).
- The umbrella chart still carries `openhands.workspace.*` defaults as a temporary compatibility layer for older overlays, but `workspace.*` is deprecated and should not be used in new overlays.
- The shipped `values-k3d.yaml` overlay keeps `openhands.persistence.enabled=false`, while `values-k3s.yaml` enables `openhands.persistence` with a persistent PVC and explicit size/storage class defaults.
- Keep extra operator-defined volume mounts away from `/app` because that shadows the image entrypoint; the chart's own single-file `config.toml` subPath mount is the managed exception.

### Nextcloud

- Stateful user data service with significant storage growth over time.
- Enabled in the umbrella baseline, but intentionally turned off in the supported `k3d` overlay.
- Keep it on a dedicated hostname when exposing it through ingress.
- Backup and restore planning is mandatory before production use.

### Gitea

- Source control service with persistent repositories.
- Disabled in the umbrella baseline and `k3d`, then enabled by the supported `k3s` overlay.
- Intended as an internal homelab service unless you deliberately expose it.
- Back up repositories and application state.

### Paperless-ngx

- Multi-volume document pipeline with separate `data`, `media`, `consume`, and `export` persistence paths.
- Disabled in the umbrella baseline and `k3d`, then enabled by the supported `k3s` overlay.
- Default posture is internal/service-only unless ingress is intentionally enabled.

### Infisical

- In-cluster secret-management component using externalized DB/cache backends from shared services.
- Enabled in the umbrella baseline and in both supported overlays.
- Shared PostgreSQL and Redis remain the expected runtime dependencies instead of the bundled Infisical subchart dependencies.

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
