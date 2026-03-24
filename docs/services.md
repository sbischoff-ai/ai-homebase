# Services reference

This document describes umbrella defaults first, then calls out how the supported `k3d` and `k3s` overlays change that posture. Read overlay-specific behavior here alongside [`docs/configuration.md`](./configuration.md) so the values layering order stays clear.

Canonical baseline posture in this document refers to `charts/platform-stack/values.yaml` before applying `charts/platform-stack/values-k3d.yaml` or `charts/platform-stack/values-k3s.yaml`.

## Service matrix

| Service | Toggle | Baseline default | k3d posture | k3s posture | Ingress default | Persistence default | Secret requirements |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `certManager` | `certManager.enabled` | Enabled | Enabled for local smoke tests | Enabled for the productive homelab | Not ingress-exposed; installs controller, webhook, and cainjector; separate `certManager.resourcesEnabled` controls when internal CA and workload certificate resources render | No PVCs | Root CA private key remains in the Secret created by `certManager.internalCA.rootCertificate.secretName`; export only `ca.crt`, never `tls.key` |
| `openclaw` | `openclaw.enabled` | Enabled | Enabled for local smoke tests | Enabled for the productive homelab | Enabled in baseline; both overlays keep ingress on and switch to the `nginx` ingress class | Baseline PVC enabled (`10Gi`); `k3d` now keeps persistence enabled for local testing, and `k3s` grows it to `50Gi` on `local-path` | Requires `openclaw.existingSecret`; baseline expects `OPENCLAW_GATEWAY_TOKEN`, and bootstrap config renders only the populated supported provider/search keys (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `BRAVE_API_KEY`, `PERPLEXITY_API_KEY`, `GEMINI_API_KEY`, `XAI_API_KEY`, `MOONSHOT_API_KEY`) plus any hostname overrides from `bootstrap.local.toml`; remote Docker SSH Secret `openclaw-remote-docker-ssh` must provide `id_ed25519` and `known_hosts` |
| `argoCd` | `argoCd.enabled` | Disabled | Disabled during the normal local bootstrap, then enabled by the optional GitOps handoff | Disabled during the normal homelab bootstrap, then enabled by the optional GitOps handoff | Upstream server ingress is enabled when the service is enabled; baseline uses `internal-nginx`, and both overlays switch it to `nginx` | Upstream defaults | Requires a separate Argo CD repository Secret created by `scripts/bootstrap-gitops.sh`; the GitOps repo URL itself points at the in-cluster Gitea service |
| `nextcloud` | `nextcloud.enabled` | Enabled | Enabled for local smoke tests with smaller local storage | Enabled for the productive homelab | Enabled in baseline; both overlays keep ingress on and use the `nginx` ingress class | Baseline PVC enabled (`250Gi`); `k3d` shrinks it to `10Gi` on `local-path`; `k3s` keeps `250Gi` on `local-path` | Baseline expects `nextcloud-config-secrets` to provide `NEXTCLOUD_ADMIN_PASSWORD`, `POSTGRES_PASSWORD`, and `REDIS_HOST_PASSWORD`; the umbrella chart reconciles the live `nextcloud` role/database through the shared PostgreSQL bootstrap Job, and Nextcloud uses the shared Redis password through the same Secret |
| `gitea` | `gitea.enabled` | Disabled | Enabled for local source-control smoke tests | Enabled for the productive homelab | Subchart ingress is enabled when the service is enabled; baseline uses `internal-nginx`, and both overlays switch it to `nginx` | Subchart PVC is enabled by default (`120Gi`); `k3d` keeps it on with a smaller `5Gi` `local-path` volume, while `k3s` uses `120Gi` on `local-path` | `gitea.gitea.gitea.admin.existingSecret` is empty by default and should be set in overlays; the wrapper now reads database/session/cache/queue/lock settings from `gitea-config-secrets` via `gitea.gitea.gitea.additionalConfigFromEnvs`, the umbrella chart reconciles the live `gitea` role/database through a shared PostgreSQL bootstrap Job, and the Gitea workload waits until direct SQL login to `gitea@gitea` succeeds before startup |
| `vaultwarden` | `vaultwarden.enabled` | Disabled | Enabled for local password-manager smoke tests | Enabled for the productive homelab | Baseline ingress is enabled when the service is enabled; both overlays keep ingress on and switch it to the `nginx` ingress class | Baseline PVC enabled (`20Gi`); `k3d` keeps it on with a smaller `5Gi` `local-path` volume, while `k3s` uses `20Gi` on `local-path` | Requires `vaultwarden.databaseUrlSecret`; baseline expects `vaultwarden-config-secrets` to provide `DATABASE_URL` and `VAULTWARDEN_DB_PASSWORD`, and bootstrap config can also add `ADMIN_TOKEN` to that same Secret so the Vaultwarden admin panel is available after bootstrap |
| `paperless-ngx` | `paperlessNgx.enabled` | Disabled | Enabled for local document-pipeline smoke tests | Enabled for the productive homelab | Baseline ingress is enabled when the service is enabled; both overlays keep ingress on and switch it to the `nginx` ingress class | Baseline enables all four PVCs (`data`, `media`, `consume`, `export`); `k3d` keeps them enabled with smaller `local-path` volumes, and `k3s` enables all four PVCs on `local-path` | Baseline expects `paperless-config-secrets` to provide `PAPERLESS_SECRET_KEY`, `PAPERLESS_ADMIN_PASSWORD`, `PAPERLESS_DB_PASSWORD`, and `PAPERLESS_REDIS`; the umbrella chart reconciles the live `paperless` role/database through the shared PostgreSQL bootstrap Job, and Paperless uses the shared Redis URL through the same Secret |

## Per-service notes

### cert-manager

- Installed through the umbrella chart as the standard in-cluster certificate controller stack.
- Baseline posture enables CRD installation plus the controller, webhook, and cainjector deployments.
- Upstream cert-manager chart values are configured under the canonical umbrella key `cert-manager.*`, while umbrella-specific toggles and PKI resources stay under `certManager.*`.
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
- The chart renders `openclaw.json` from structured `openclaw.*` values and uses it only to seed `/home/node/.openclaw/openclaw.json` on first start; later UI changes persist on the OpenClaw PVC and are not overwritten on redeploy. The shipped workspace default is the absolute path `/home/node/.openclaw/workspace` so the persisted config does not expand to `/home/node/.openclaw/.openclaw/workspace`.
- OpenClaw defaults to Docker sandboxing with `mode=non-main` and `scope=agent`, plus explicit `docker.*` and `browser.*` sandbox image/runtime settings rendered into `openclaw.json`; the chart intentionally omits `backend` because the shipped OpenClaw image already defaults it to Docker.
- The browser sandbox config exposes `openclaw.agents.defaults.sandbox.browser.cdpSourceRange` so operators can match the CIDR that reaches the remote browser container's CDP port.
- `openclaw.remoteDocker.*` exports `DOCKER_HOST` and `HOME`, then mounts SSH credentials for Docker's `ssh://` transport so OpenClaw launches Docker/browser sandboxes on the standard remote daemon without changing the OpenClaw backend away from `docker`. During bootstrap, `scripts/bootstrap-config.py` seeds `agents.defaults.model.primary` from the first available model-provider key in `bootstrap.local.toml` and writes provider/search secret key mappings only for populated config entries, so first chat is usable without manually editing the Control UI and optional keys do not become accidental runtime requirements.
- Keep OpenClaw itself on HTTP behind ingress TLS termination. Set `openclaw.openclaw.gateway.controlUi.allowedOrigins` to the external HTTPS origin and `openclaw.openclaw.gateway.trustedProxies` to the ingress-controller source CIDRs or IPs that forward client headers.
- The Secret named by `openclaw.remoteDocker.ssh.secretName` must contain non-empty `id_ed25519` and `known_hosts` keys because the init container validates and copies only those files before the main container starts.
- The `remote-docker-ssh-permissions` init container is expected to run as UID/GID `0` with `allowPrivilegeEscalation: false`, a read-only root filesystem, and only the `CHOWN` capability retained while it first locks `/ssh-target` down to OpenSSH-safe modes and then hands the copied SSH files to the main container, which still runs as non-root UID/GID `1000`.
- The copied SSH material is intentionally normalized to OpenSSH-safe permissions before the main container starts: the SSH directory is `0700`, `id_ed25519` is `0600`, and `known_hosts` remains readable at `0644`.
- If OpenClaw is stuck in `Init:CrashLoopBackOff`, inspect the `remote-docker-ssh-permissions` init-container logs first; missing or empty `id_ed25519` / `known_hosts` entries in `remoteDocker.ssh.secretName`, any failure while locking down `/ssh-target` modes, or any failure to hand the prepared directory to UID/GID `1000` are supported failure modes with explicit stderr output.
- The supported posture is an external Incus VM (`openclaw-sandbox`) as a single-purpose remote Docker appliance, while the VM remains outside Helm; chart values control only how the OpenClaw pod reaches it.

### Argo CD

- Disabled during the normal bootstrap path and added only by `scripts/bootstrap-gitops.sh`.
- Wrapped by a local `charts/argo-cd` chart so the repo controls the upstream chart version and ingress defaults explicitly.
- `bootstrap.local.toml` can seed the Argo CD login through `[services.argocd.admin]`. `user = "admin"` updates the built-in admin account, while any other safe local username is rendered as an Argo CD local account with admin RBAC during the GitOps bootstrap flow.
- The GitOps handoff creates a dedicated Gitea robot user and private repo, pushes a self-contained snapshot of the local charts plus cluster values into that repo, and then registers the repo in Argo CD with a repository Secret in the cluster.
- Argo CD reads the GitOps repo through the in-cluster Gitea service URL rather than the public ingress hostname, so repo access does not depend on client-side CA trust.
- The current GitOps posture uses an app-of-apps root with a single child `platform-stack` `Application`; sync remains manual after bootstrap.

### Nextcloud

- Stateful user data service with significant storage growth over time.
- Enabled in the umbrella baseline and in both supported overlays; the `k3d` overlay keeps the service small enough for local smoke tests, while `k3s` keeps the larger production-sized PVC.
- The chart now treats shared PostgreSQL and shared Redis as the canonical runtime posture. Baseline values point Nextcloud at `platform-stack-shared-postgresql` with a dedicated `nextcloud` database/user and at `platform-stack-shared-redis` for cache/session state.
- `scripts/bootstrap-secrets.sh` creates or refreshes `nextcloud-config-secrets` with `NEXTCLOUD_ADMIN_PASSWORD`, `POSTGRES_PASSWORD`, and `REDIS_HOST_PASSWORD`, while the bootstrap-generated values layer sets `nextcloud.admin.user` from the shared admin profile or service override in `bootstrap.local.toml`. The chart-managed shared PostgreSQL bootstrap Job reconciles the live `nextcloud` role/database during install and upgrade, so reusing PostgreSQL storage no longer depends on first-boot init scripts alone.
- The main Nextcloud container intentionally stays root for image bootstrap because the official entrypoint writes PHP config and synchronizes the application tree into the mounted PVC, while the cron worker runs as UID/GID `33` (`www-data`) because `php occ` and `cron.php` require the data-directory owner.
- Keep it on a dedicated hostname when exposing it through ingress.
- Backup and restore planning is mandatory before production use.

### Gitea

- Source control service with persistent repositories.
- Disabled in the umbrella baseline, then enabled by both supported overlays with `k3d` sized down for local testing and `k3s` sized for the homelab.
- Baseline image defaults set `gitea.gitea.image.repository=gitea` and keep `rootless=true`, so the upstream chart resolves workloads to `docker.gitea.com/gitea:1.25.5-rootless` instead of the invalid `docker.gitea.com/docker.gitea.com/gitea` pull path.
- The `configure-gitea` init container must see the complete `[database]` section in `/data/gitea/conf/app.ini` before it can run migrations. The shipped defaults therefore load `gitea-config-secrets` through `gitea.gitea.gitea.additionalConfigFromEnvs` so the `init-app-ini` container writes the secret-backed `database`, `session`, `cache`, `queue`, and `global_lock` settings into `app.ini` before startup. The wrapper also injects a `preExtraInitContainers` SQL gate that waits until `psql` can connect as `gitea` to the `gitea` database, and it disables the upstream `valkey` and `valkey-cluster` subcharts so Gitea uses the umbrella chart's shared Redis instance instead of rendering a nested cache dependency.
- The umbrella chart now renders `shared-postgresql-bootstrap-job.yaml` whenever shared PostgreSQL is enabled and at least one of Gitea or Vaultwarden is enabled. That Job waits for `platform-stack-shared-postgresql:5432`, then idempotently reconciles the `gitea` and/or `vaultwarden` roles/databases against the live server during install/upgrade. The hook now runs with `restartPolicy: Never` plus `terminationMessagePolicy: FallbackToLogsOnError` so a failed attempt stays behind as a failed pod and Kubernetes preserves the tail of the container logs in the termination message for debugging.
- `scripts/bootstrap-secrets.sh` creates `gitea-config-secrets` with env-style `GITEA__...` keys plus `gitea-admin-secret` for the upstream chart's admin bootstrap. It reuses the existing `GITEA__database__PASSWD` and admin password values by default, so password rotation remains an explicit operator action unless you change the bootstrap config.
- Intended as an internal homelab service unless you deliberately expose it.
- Back up repositories and application state.

### Vaultwarden

- Password-manager service deployed behind ingress with Vaultwarden's `DATABASE_URL` pointing at the shared PostgreSQL service, a dedicated `vaultwarden` database role, and a companion `VAULTWARDEN_DB_PASSWORD` secret key for bootstrap/wait logic.
- Disabled in the umbrella baseline, then enabled by both supported overlays with `k3d` sized down for local smoke tests and `k3s` sized for the homelab.
- The chart pins `ghcr.io/dani-garcia/vaultwarden:1.35.4`, mounts `/data` for persisted attachments/config, and derives `DOMAIN` from the ingress hostname unless you override `vaultwarden.appConfig.domain`.
- `scripts/bootstrap-secrets.sh` creates the `vaultwarden-config-secrets` Secret with `DATABASE_URL` and `VAULTWARDEN_DB_PASSWORD`, and it also carries `ADMIN_TOKEN` when you set `vaultwarden_admin_token` in `bootstrap.local.toml`. The chart-managed shared PostgreSQL bootstrap Job uses the explicit password key to reconcile the live `vaultwarden` role/database without parsing the URL, and the Vaultwarden Deployment has an init container that waits until a direct SQL login succeeds. Re-running the bootstrap reuses the existing `VAULTWARDEN_DB_PASSWORD` and `ADMIN_TOKEN` values by default when the config leaves them empty. Vaultwarden initial-user creation is still not chart-managed in this repo; use the admin panel enabled by `ADMIN_TOKEN` to create users manually.
- Keep Vaultwarden on HTTPS externally; the app itself stays on HTTP behind ingress TLS termination, and `DOMAIN` should match the public ingress URL so links, WebAuthn, and attachment downloads work correctly.

### Paperless-ngx

- Multi-volume document pipeline with separate `data`, `media`, `consume`, and `export` persistence paths.
- Disabled in the umbrella baseline, then enabled by both supported overlays with `k3d` sized down for local smoke tests and `k3s` sized for the homelab.
- Baseline values point Paperless at the shared PostgreSQL and Redis services with a dedicated `paperless` database/user and a Secret-backed Redis URL. `scripts/bootstrap-secrets.sh` creates or refreshes `paperless-config-secrets` with `PAPERLESS_SECRET_KEY`, `PAPERLESS_ADMIN_PASSWORD`, `PAPERLESS_DB_PASSWORD`, and `PAPERLESS_REDIS`, while the bootstrap-generated values layer sets `paperlessNgx.admin.user` and `paperlessNgx.admin.mail` from the shared admin profile or service override in `bootstrap.local.toml`.
- The umbrella chart reconciles the live `paperless` role/database through the shared PostgreSQL bootstrap Job, and the Paperless StatefulSet waits until a direct SQL login as `paperless` to the `paperless` database succeeds before startup so the app does not race the bootstrap hook.
- The upstream container currently needs to start as UID/GID `0` so its s6 preinit can normalize `/run`, while the chart still drops Linux capabilities and disables privilege escalation.
- Keep it on a dedicated hostname when exposing it through ingress.

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
