# Services reference

This document describes umbrella defaults first, then calls out how the supported `k3d` and `k3s` overlays change that posture. Read overlay-specific behavior here alongside [`docs/configuration.md`](./configuration.md) so the values layering order stays clear.

Canonical baseline posture in this document refers to `charts/platform-stack/values.yaml` before applying `charts/platform-stack/values-k3d.yaml` or `charts/platform-stack/values-k3s.yaml`.

## Service matrix

| Service | Toggle | Baseline default | k3d posture | k3s posture | Ingress default | Persistence default | Secret requirements |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `certManager` | `certManager.enabled` | Enabled | Enabled for local smoke tests | Enabled for the productive homelab | Not ingress-exposed; installs controller, webhook, and cainjector; separate `certManager.resourcesEnabled` controls when internal CA and workload certificate resources render | No PVCs | Root CA private key remains in the Secret created by `certManager.internalCA.rootCertificate.secretName`; export only `ca.crt`, never `tls.key` |
| `openclaw` | `openclaw.enabled` | Enabled | Enabled for local smoke tests | Enabled for the productive homelab | Enabled in baseline; both overlays keep ingress on and switch to the `nginx` ingress class | Baseline PVC enabled (`10Gi`); `k3d` now keeps persistence enabled for local testing, and `k3s` grows it to `50Gi` on `local-path` | Requires `openclaw.existingSecret`; baseline expects `OPENCLAW_GATEWAY_TOKEN`, and `k3d` also maps `OPENAI_API_KEY`; remote Docker SSH Secret `openclaw-remote-docker-ssh` must provide `id_ed25519` and `known_hosts` |
| `nextcloud` | `nextcloud.enabled` | Enabled | Disabled to keep local smoke tests light | Enabled for the productive homelab | Enabled in baseline; `k3s` keeps ingress on and moves it to the `nginx` ingress class | Baseline PVC enabled (`250Gi`); `k3d` disables the service and persistence; `k3s` keeps persistence on with `250Gi` on `local-path` | `existingSecret` is optional in baseline and empty by default; provide one in overlays when operator-managed app secrets are needed |
| `gitea` | `gitea.enabled` | Disabled | Disabled | Enabled for the productive homelab | Subchart ingress is enabled when the service is enabled; baseline uses `internal-nginx`, and `k3s` switches it to `nginx` | Subchart PVC is enabled by default (`120Gi`); it is inactive until `gitea.enabled=true`, which only happens in `k3s` among supported overlays | `gitea.gitea.admin.existingSecret` is empty by default and should be set in overlays; database, session, cache, queue, and lock credentials are expected through environment-backed Secret values |
| `paperless-ngx` | `paperlessNgx.enabled` | Disabled | Disabled | Enabled for the productive homelab | Baseline ingress is enabled when the service is enabled; `k3s` keeps ingress on and switches it to the `nginx` ingress class | Baseline enables all four PVCs (`data`, `media`, `consume`, `export`); `k3d` disables the service and each PVC; `k3s` enables the service with all four PVCs on `local-path` | `existingSecret` is optional in baseline and empty by default; provide Secret references in overlays for mail, OCR, or other runtime integrations |
| `infisical` | `infisical.enabled` | Enabled | Enabled for local smoke tests | Enabled for the productive homelab | Enabled in baseline; both overlays keep ingress on and switch to the `nginx` ingress class | No Infisical-managed PVCs are enabled here because the chart is wired to shared PostgreSQL and Redis services instead of bundled stateful dependencies | Baseline expects `infisical.infisical.kubeSecretRef=infisical-secrets`; `autoBootstrap.credentialSecret.name` defaults to `infisical-bootstrap-credentials` when bootstrap automation is turned on |

## Per-service notes

### cert-manager

- Installed through the umbrella chart as the standard in-cluster certificate controller stack.
- Baseline posture enables CRD installation plus the controller, webhook, and cainjector deployments.
- `certManager.resourcesEnabled=false` by default so first-install renders can succeed before the cert-manager CRDs exist; enable it only after the cert-manager CRDs and deployments are ready.
- `./scripts/install.sh` automatically performs that two-step bootstrap whenever `certManager.enabled=true`: first it installs the controller stack with `certManager.resourcesEnabled=false`, then it waits for the CRDs and cert-manager deployments/webhook to become ready before applying again with `certManager.resourcesEnabled=true`.
- `certManager.internalCA.enabled=true` uses cert-manager's standard SelfSigned → CA bootstrapping pattern:
  1. a bootstrap SelfSigned `ClusterIssuer`,
  2. a root CA `Certificate` that writes the CA keypair Secret, and
  3. a CA `ClusterIssuer` that signs workload certificates.
- `certManager.openclawCertificate.enabled=true` issues the OpenClaw ingress certificate into the same Secret referenced by `openclaw.ingress.tls[0].secretName`.
- Clients must trust the internal root CA certificate before they can validate the OpenClaw HTTPS endpoint.
- Export only the public CA certificate, for example:

  ```bash
  kubectl get secret platform-stack-root-ca -n <namespace> -o jsonpath='{.data.ca\.crt}' | base64 -d > platform-stack-root-ca.crt
  ```

- Never export or distribute the CA private key (`tls.key`).

### OpenClaw

- General AI assistant service for user-facing chat/API use.
- The chart renders `openclaw.json` from structured `openclaw.*` values.
- OpenClaw defaults to Docker sandboxing with `mode=non-main` and `scope=agent`, plus explicit `docker.*` and `browser.*` sandbox image/runtime settings rendered into `openclaw.json`; the chart intentionally omits `backend` because the shipped OpenClaw image already defaults it to Docker.
- The browser sandbox config exposes `openclaw.agents.defaults.sandbox.browser.cdpSourceRange` so operators can match the CIDR that reaches the remote browser container's CDP port.
- `openclaw.remoteDocker.*` exports `DOCKER_HOST` and `HOME`, then mounts SSH credentials for Docker's `ssh://` transport so OpenClaw launches Docker/browser sandboxes on the standard remote daemon without changing the OpenClaw backend away from `docker`.
- Keep OpenClaw itself on HTTP behind ingress TLS termination. Set `openclaw.openclaw.gateway.controlUi.allowedOrigins` to the external HTTPS origin and `openclaw.openclaw.gateway.trustedProxies` to the ingress-controller source CIDRs or IPs that forward client headers.
- The Secret named by `openclaw.remoteDocker.ssh.secretName` must contain non-empty `id_ed25519` and `known_hosts` keys because the init container validates and copies only those files before the main container starts.
- The `remote-docker-ssh-permissions` init container is expected to run as UID/GID `0` with `allowPrivilegeEscalation: false`, a read-only root filesystem, and only the `CHOWN` capability retained while it first locks `/ssh-target` down to OpenSSH-safe modes and then hands the copied SSH files to the main container, which still runs as non-root UID/GID `1000`.
- The copied SSH material is intentionally normalized to OpenSSH-safe permissions before the main container starts: the SSH directory is `0700`, `id_ed25519` is `0600`, and `known_hosts` remains readable at `0644`.
- If OpenClaw is stuck in `Init:CrashLoopBackOff`, inspect the `remote-docker-ssh-permissions` init-container logs first; missing or empty `id_ed25519` / `known_hosts` entries in `remoteDocker.ssh.secretName`, any failure while locking down `/ssh-target` modes, or any failure to hand the prepared directory to UID/GID `1000` are supported failure modes with explicit stderr output.
- The supported posture is an external Incus VM (`openclaw-sandbox`) as a single-purpose remote Docker appliance, while the VM remains outside Helm; chart values control only how the OpenClaw pod reaches it.

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
