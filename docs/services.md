# Services reference

This document describes umbrella defaults first, then calls out how the supported `k3d` and `k3s` overlays change that posture. Read overlay-specific behavior here alongside [`docs/configuration.md`](./configuration.md) so the values layering order stays clear.

Canonical baseline posture in this document refers to `charts/platform-stack/values.yaml` before applying `charts/platform-stack/values-k3d.yaml` or `charts/platform-stack/values-k3s.yaml`.

## Service matrix

| Service | Toggle | Baseline default | k3d posture | k3s posture | Ingress default | Persistence default | Secret requirements |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `certManager` | `certManager.enabled` | Enabled | Enabled for local smoke tests | Enabled for the productive homelab | Not ingress-exposed; installs controller, webhook, and cainjector; separate `certManager.resourcesEnabled` controls when internal CA and workload certificate resources render | No PVCs | Root CA private key remains in the Secret created by `certManager.internalCA.rootCertificate.secretName`; export only `ca.crt`, never `tls.key` |
| `openclaw` | `openclaw.enabled` | Enabled | Enabled for local smoke tests | Enabled for the productive homelab | Enabled in baseline; both overlays keep ingress on and switch to the `nginx` ingress class | Baseline persistence enabled (`10Gi`); the supported `k3d` and `k3s` overlays now use a shared hostPath-backed OpenClaw state directory so the gateway pod and remote Docker host see the same `/home/node/.openclaw` tree | Requires `openclaw-secrets` for `OPENCLAW_GATEWAY_TOKEN` and provider/search keys, `coder-credentials` for the sandbox Gitea/registry passwords, and `openclaw-remote-docker-ssh` for `id_ed25519` and `known_hosts`; the committed Secret manifests should be SOPS-encrypted |
| `argoCd` | `argoCd.enabled` | Disabled | Disabled in the first Helm apply, then enabled automatically by the integrated GitOps handoff before bootstrap completion | Disabled in the first Helm apply, then enabled automatically by the integrated GitOps handoff before bootstrap completion | Upstream server ingress is enabled when the service is enabled; baseline uses `internal-nginx`, and both overlays switch it to `nginx` | Upstream defaults | Requires a separate Argo CD repository Secret created by the integrated `scripts/bootstrap-gitops.sh` phase; the GitOps repo URL itself points at the in-cluster Gitea service |
| `nextcloud` | `nextcloud.enabled` | Enabled | Enabled for local smoke tests with smaller local storage | Enabled for the productive homelab | Baseline renders a private ingress; `k3d` keeps only the private hostname, while `k3s` can also render a second public ingress when `hosts.nextcloud_public` is set in `bootstrap.local.toml` | Baseline PVC enabled (`250Gi`); `k3d` shrinks it to `10Gi` on `local-path`; `k3s` keeps `250Gi` on `local-path` | Baseline expects a SOPS-managed `nextcloud-config-secrets` Secret providing `NEXTCLOUD_ADMIN_PASSWORD`, `POSTGRES_PASSWORD`, and `REDIS_HOST_PASSWORD`; the umbrella chart reconciles the live `nextcloud` role/database through the shared PostgreSQL bootstrap Job, and Nextcloud uses the shared Redis password through the same Secret |
| `nextcloudMcp` | `nextcloudMcp.enabled` | Enabled | Enabled for local smoke tests | Enabled for the productive homelab | Baseline ingress is enabled on a dedicated hostname; `k3d` and `k3s` both switch it to the `nginx` ingress class in the supported overlays | No PVCs | `scripts/bootstrap-secrets.sh` creates `openclaw-nextcloud-mcp-secrets` with the dedicated `openclaw` Nextcloud credentials and the precomputed `OPENCLAW_NEXTCLOUD_MCP_AUTH_HEADER`; external clients authenticate with their own Nextcloud users through Basic Auth when the service runs in `multi_user_basic` mode |
| `qdrant` | `qdrant.enabled` | Enabled | Enabled for local smoke tests | Enabled for the productive homelab | Baseline ingress enabled on a dedicated hostname; overlays switch to `nginx` ingress class | PVC enabled (`100Gi` baseline; `10Gi` on `k3d`, `100Gi` on `k3s`) | No secret required in the baseline local posture |
| `qdrantMcp` | `qdrantMcp.enabled` | Enabled | Enabled for local smoke tests | Enabled for the productive homelab | Baseline ingress enabled on a dedicated hostname; overlays switch to `nginx` ingress class | No PVCs | No secret required in the baseline posture; the default runtime uses FastEmbed |
| `memgraph` | `memgraph.enabled` | Enabled | Enabled for local smoke tests | Enabled for the productive homelab | Baseline ingress enabled on a dedicated hostname for the HTTP surface; overlays switch to `nginx` ingress class | PVC enabled (`100Gi` baseline; `10Gi` on `k3d`, `150Gi` on `k3s`) | No secret required in the baseline posture; agents use the in-cluster Bolt Service for CLI access |
| `memgraphLab` | `memgraphLab.enabled` | Enabled | Enabled for local smoke tests | Enabled for the productive homelab | Baseline ingress enabled on a dedicated hostname; overlays switch to `nginx` ingress class | No PVCs | No secret required in the baseline posture; defaults point Lab at the in-cluster Memgraph Service |
| `gitea` | `gitea.enabled` | Disabled | Enabled for local source-control smoke tests | Enabled for the productive homelab | Subchart ingress is enabled when the service is enabled; baseline uses `internal-nginx`, and both overlays switch it to `nginx` | Subchart PVC is enabled by default (`120Gi`); `k3d` keeps it on with a smaller `5Gi` `local-path` volume, while `k3s` uses `120Gi` on `local-path` | `gitea.gitea.gitea.admin.existingSecret` is empty by default and should be set in overlays; the wrapper now reads database/session/cache/queue/lock settings from `gitea-config-secrets` via `gitea.gitea.gitea.additionalConfigFromEnvs`, the umbrella chart reconciles the live `gitea` role/database through a shared PostgreSQL bootstrap Job, and the Gitea workload waits until direct SQL login to `gitea@gitea` succeeds before startup |
| `registry` | `registry.enabled` | Disabled | Enabled for local image-publish smoke tests | Enabled for the productive homelab | Ingress is enabled when the service is enabled; baseline uses `internal-nginx`, and both overlays switch it to `nginx` with internal-CA TLS | PVC enabled by default (`50Gi` baseline); `k3d` shrinks it to `5Gi` on `local-path`, while `k3s` uses `50Gi` on `local-path` | Requires `registry-auth-secret`; bootstrap creates `username`, `password`, and `htpasswd` keys, and coder bootstrap uses the same credentials for registry pushes |
| `vaultwarden` | `vaultwarden.enabled` | Disabled | Enabled for local password-manager smoke tests | Enabled for the productive homelab | Baseline ingress is enabled when the service is enabled; both overlays keep ingress on and switch it to the `nginx` ingress class | Baseline PVC enabled (`20Gi`); `k3d` keeps it on with a smaller `5Gi` `local-path` volume, while `k3s` uses `20Gi` on `local-path` | Requires `vaultwarden.databaseUrlSecret`; baseline expects `vaultwarden-config-secrets` to provide `DATABASE_URL` and `VAULTWARDEN_DB_PASSWORD`, and bootstrap config can also add `ADMIN_TOKEN` to that same Secret so the Vaultwarden admin panel is available after bootstrap |
| `postfixRelay` | `postfixRelay.enabled` | Disabled | Enabled for local app-mail smoke tests | Enabled for the productive homelab | Not ingress-exposed; applications use the in-cluster Service `platform-stack-postfix-relay:587` | No PVCs | No Secret is required for the default direct-delivery posture; the relay reads sender domain and SMTP hostname from `bootstrap.local.toml` `[mail]` |
| `paperless-ngx` | `paperlessNgx.enabled` | Disabled | Enabled for local document-pipeline smoke tests | Enabled for the productive homelab | Baseline ingress is enabled when the service is enabled; both overlays keep ingress on and switch it to the `nginx` ingress class | Baseline enables all four PVCs (`data`, `media`, `consume`, `export`); `k3d` keeps them enabled with smaller `local-path` volumes, and `k3s` enables all four PVCs on `local-path` | Baseline expects `paperless-config-secrets` to provide `PAPERLESS_SECRET_KEY`, `PAPERLESS_ADMIN_PASSWORD`, `PAPERLESS_DB_PASSWORD`, and `PAPERLESS_REDIS`; the umbrella chart reconciles the live `paperless` role/database through the shared PostgreSQL bootstrap Job, and Paperless uses the shared Redis URL through the same Secret |

The supported `k3s` posture is currently a deliberately single-node deployment on a host in the Hetzner A42U class. Overlay resource values therefore aim to keep the current stateful stack comfortable on that machine while still leaving room for future additions such as Qdrant, Memgraph, and coder-deployed apps.

## Per-service notes

### cert-manager

- Installed through the umbrella chart as the standard in-cluster certificate controller stack.
- Baseline posture enables CRD installation plus the controller, webhook, and cainjector deployments.
- Upstream cert-manager chart values are configured under the canonical umbrella key `cert-manager.*`, while umbrella-specific toggles and PKI resources stay under `certManager.*`.
- `certManager.resourcesEnabled=false` by default so first-install renders can succeed before the cert-manager CRDs exist; enable it only after the cert-manager CRDs and deployments are ready.
- `./scripts/bootstrap-stack.sh` automatically performs that two-step bootstrap whenever `certManager.enabled=true`: first it installs the controller stack with `certManager.resourcesEnabled=false`, then it waits for the CRDs and cert-manager deployments/webhook to become ready before applying again with `certManager.resourcesEnabled=true`.
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
- The chart renders `openclaw.json` from structured `openclaw.*` values and uses it only to seed `/home/node/.openclaw/openclaw.json` on first start; later UI changes persist in the mounted OpenClaw state directory and are not overwritten on redeploy. The shipped main workspace default is the absolute path `/home/node/.openclaw/workspace`, and additional bootstrapped agents use sibling paths such as `/home/node/.openclaw/workspace-architect`, `/home/node/.openclaw/workspace-coder`, and `/home/node/.openclaw/workspace-watchdog`.
- The seeded OpenClaw config now also includes a repo-managed `openclaw.cron` scheduler block with the default store path and retention settings. The recurring jobs themselves are seeded after startup through the documented `openclaw cron` CLI, currently creating the standard watchdog heartbeat/platform sweep/daily digest jobs plus the archivist nightly grooming job only when they are missing from the persistent cron store.
- OpenClaw defaults to Docker sandboxing with an explicit `backend=docker`, `mode=non-main`, and `scope=agent`, plus explicit `docker.*` and `browser.*` sandbox image/runtime settings rendered into `openclaw.json`.
- The regular, archivist, and coder Docker sandbox image refs now default to fully qualified in-cluster registry names under the coder namespace instead of mutable local Docker tags. The browser sandbox image is unchanged.
- The chart now also seeds explicit `main`, `architect`, `coder`, `archivist`, and `watchdog` agents, top-level `tools.agentToAgent`, `tools.sessions.visibility=all`, plus `commands.mcp`, top-level `mcp.servers.nextcloud`, and a repo-managed global `skills.allowBundled` list on first start. Bootstrap reads the agent models from `bootstrap.local.toml`: `main` keeps the shared sandbox defaults, `archivist` stays on `sandbox.mode=non-main` but now gets its own sandbox image with `neo4j-driver` baked in for Bolt access, `coder` gets an agent-specific `sandbox.mode=all` override plus its own sandbox image with developer tooling, Codex CLI, and coder-specific sandbox env/setup, and `watchdog` gets `sandbox.mode=off` so it always runs in the gateway.
- The default multi-agent posture is: `main` orchestrates, manages user-facing work, and handles ordinary non-coding tasks; `architect` owns planning, design, specifications, durable project structure, and task decomposition; `coder` executes code/repo/GitOps work through a Sonnet-orchestrator-plus-Codex pattern; `archivist` owns Memgraph schema stewardship, graph curation, and graph-linked Qdrant grooming; and `watchdog` owns low-cost heartbeat-driven monitoring, polling, cron-style checks, triage, delegation, and escalation. `main` is intentionally not the project author for durable planning artifacts: project folders, specs, and task breakdowns belong with `architect`. The chart seeds role files directly into each workspace on first start so delegated specialist sessions get durable `AGENTS.md` and `TOOLS.md` guidance instead of depending on ad hoc chat context alone, and it now supports nested workspace seeding for coder-local skills under `<workspace>/skills`.
- For HTTP-backed MCP servers, the supported pattern is: keep the OpenClaw MCP entry at gateway level, place the bridge at the shared runtime path `/opt/openclaw-runtime/mcp/mcp-http-bridge.mjs`, and have that launcher try the in-cluster Service URL first and the ingress hostname second. That split is required because the gateway pod can use cluster DNS directly, while Docker sandboxes in the Incus VM reach the same MCP service through the VM/container DNS overrides and ingress listener address.
- The browser sandbox config exposes `openclaw.agents.defaults.sandbox.browser.cdpSourceRange` so operators can match the CIDR that reaches the remote browser container's CDP port.
- `openclaw.remoteDocker.*` exports `DOCKER_HOST` and `HOME`, injects a Docker CLI into the pod through `remoteDocker.cli.*`, and mounts SSH credentials for Docker's `ssh://` transport so OpenClaw launches Docker/browser sandboxes on the standard remote daemon. The main OpenClaw image still needs an `ssh` client; the init sequence now fails early if that binary is missing. During bootstrap, `scripts/bootstrap-config.py` reads each agent's `model` plus optional `fallback_models` from `bootstrap.local.toml`, validates that the matching provider keys are present in `[providers]` for both primaries and fallbacks, and writes provider/search secret key mappings only for populated config entries.
- The supported watchdog/session-logs posture also assumes the gateway runtime has `jq` and `rg`. The repo-managed gateway image at `images/openclaw-remote-docker/Dockerfile` now carries `docker`, `ssh`, `jq`, and `ripgrep`, and the local `k3d` overlay uses that image so watchdog can rely on `session-logs` from day one.
- Bootstrap now also seeds a second coder-owned Gitea repo for sandbox image source. The intended split is: GitOps repo for cluster definitions, sandbox-images repo for OpenClaw sandbox runtime source, and the in-cluster registry as the canonical runtime distribution point.
- Remote Docker sandbox workspaces are bind-mounted from `/home/node/.openclaw/sandboxes/...`, so the gateway pod and the Incus VM must share the same OpenClaw state directory at that absolute path. The supported `k3d` and `k3s` flows now prepare a shared host directory for that state and mount it into the VM before bootstrapping OpenClaw.
- In the supported coder posture, `/workspace` is the working tree and `/workspace/.home` is the persistent writable home/state area. The seeded sandbox setup exports `HOME=/workspace/.home`, `CODEX_HOME=/workspace/.home/.codex`, and XDG directories under that path so Codex CLI and related developer tooling keep durable writable state inside the same sandbox mount.
- Any ingress hostname that sandboxed agents must call directly, including OpenClaw itself for `sessions_send` / `sessions_spawn`, must resolve inside both the Incus VM and its nested Docker containers. The supported bootstrap path handles that through `incus-vm-up.sh --resolve-host ...`, which writes the VM `/etc/hosts` entries and the Docker-side `dnsmasq` overrides together for OpenClaw, Nextcloud, Nextcloud MCP, Gitea, the registry, and Memgraph.
- On `k3s`, the intended companion host flow is `install-k3s-ubuntu-2404.sh` followed by `k3s-homelab-sandbox-up.sh` before `bootstrap-stack.sh`; the shared bootstrap path now auto-discovers the resulting Incus connection info and rewrites `openclaw.remoteDocker.dockerHost` to the concrete listener address when that env file exists.
- OpenClaw's seeded MCP definition makes the Nextcloud MCP server available to all agents. In practice, the stack treats that as a shared-account tool surface governed by workspace instructions rather than deny lists: `main` owns the shared calendar, reminders, todos, and user-facing coordination state, but should not create project folders or durable planning docs; `architect` uses Nextcloud for plans/design docs and planning todos; `coder` only uses it when durable implementation context or handoff material is genuinely useful; and `watchdog` stays lightweight and uses it only when a durable monitoring note or escalation trail is genuinely useful. The same pattern applies to the bundled skill allowlist: it is global, while effective per-agent separation comes from runtime binaries and the seeded role files.
- Keep OpenClaw itself on HTTP behind ingress TLS termination. Set `openclaw.openclaw.gateway.controlUi.allowedOrigins` to the external HTTPS origin and `openclaw.openclaw.gateway.trustedProxies` to the ingress-controller source CIDRs or IPs that forward client headers.
- The Secret named by `openclaw.remoteDocker.ssh.secretName` must contain non-empty `id_ed25519` and `known_hosts` keys because the init container validates and copies only those files before the main container starts.
- The `remote-docker-ssh-permissions` init container is expected to run as UID/GID `0` with `allowPrivilegeEscalation: false`, a read-only root filesystem, and only the `CHOWN` capability retained while it first locks `/ssh-target` down to OpenSSH-safe modes and then hands the copied SSH files to the main container, which still runs as non-root UID/GID `1000`.
- The copied SSH material is intentionally normalized to OpenSSH-safe permissions before the main container starts: the SSH directory is `0700`, `id_ed25519` is `0600`, and `known_hosts` remains readable at `0644`.
- If OpenClaw is stuck in `Init:CrashLoopBackOff`, inspect the `remote-docker-ssh-permissions` init-container logs first; missing or empty `id_ed25519` / `known_hosts` entries in `remoteDocker.ssh.secretName`, any failure while locking down `/ssh-target` modes, or any failure to hand the prepared directory to UID/GID `1000` are supported failure modes with explicit stderr output.
- The supported posture is an external Incus VM (`openclaw-sandbox`) as a single-purpose remote Docker appliance, while the VM remains outside Helm; chart values control only how the OpenClaw pod reaches it.

### Argo CD

- Disabled in the first shared Helm apply and then enabled automatically by the integrated GitOps phase before bootstrap completion.
- Wrapped by a local `charts/argo-cd` chart so the repo controls the upstream chart version and ingress defaults explicitly.
- `bootstrap.local.toml` can seed the Argo CD login through `[services.argocd.admin]`. `user = "admin"` updates the built-in admin account, while any other safe local username is rendered as an Argo CD local account with admin RBAC during the GitOps bootstrap flow.
- The integrated GitOps phase creates or updates the dedicated coder Gitea user and private repo, pushes a self-contained snapshot of the local charts plus cluster values into that repo, registers the repo in Argo CD with a repository Secret in the cluster, triggers the initial sync, and waits for the resulting Argo applications to become `Synced` and `Healthy`.
- Argo CD reads the GitOps repo through the in-cluster Gitea service URL rather than the public ingress hostname, so repo access does not depend on client-side CA trust.
- The current GitOps posture uses an app-of-apps root with a single child `platform-stack` `Application`; sync remains manual after bootstrap.

### Nextcloud

- Stateful user data service with significant storage growth over time.
- Enabled in the umbrella baseline and in both supported overlays; the `k3d` overlay keeps the service small enough for local smoke tests, while `k3s` keeps the larger production-sized PVC.
- The chart now treats shared PostgreSQL and shared Redis as the canonical runtime posture. Baseline values point Nextcloud at `platform-stack-shared-postgresql` with a dedicated `nextcloud` database/user and at `platform-stack-shared-redis` for cache/session state.
- Nextcloud now renders two separate ingress objects that point to the same Service: `nextcloud-private` for the private/internal host and `nextcloud-public` for the public internet host. Each ingress has its own host, TLS Secret, and `cert-manager.io/cluster-issuer` annotation. The `k3d` overlay keeps only the private ingress, while the `k3s` overlay enables the public ingress path when `hosts.nextcloud_public` is set in `bootstrap.local.toml`.
- `nextcloud-config-secrets` is now intended to come from a SOPS-encrypted manifest in `secrets/`; it must provide `NEXTCLOUD_ADMIN_PASSWORD`, `POSTGRES_PASSWORD`, and `REDIS_HOST_PASSWORD`, while the bootstrap-generated values layer still sets `nextcloud.admin.user`, `nextcloud.ingress.private.host`, optional `nextcloud.ingress.public.host`, `nextcloud.trustedDomains`, and `nextcloud.smtp.*` from `bootstrap.local.toml`. Both hostnames are added to `NEXTCLOUD_TRUSTED_DOMAINS` when present, and the chart uses `TRUSTED_PROXIES` plus `APACHE_DISABLE_REWRITE_IP=1` so forwarded host/protocol headers from ingress-nginx are trusted without forcing `OVERWRITEHOST` unless you explicitly set it.
- The chart now also supports `bootstrapApps[]`, a post-install/post-upgrade `occ` Job for converging required app-store apps. The standard stack uses it to keep `notes`, `tables`, `calendar`, and `tasks` installed and enabled.
- The chart now also supports `bootstrapUsers[]` and the standard stack uses it to keep a dedicated `openclaw` user present with Secret-backed credentials for the MCP integration. That bootstrap job now reconciles display names as well as passwords, so the rendered `displayName` stays authoritative on upgrades.
- The chart now also supports `bootstrapProjectContent[]`, a post-install/post-upgrade content-seeding Job for managed project material under `/Projects/<slug>/` and `/Notes/<slug>/`. The standard stack uses it to seed one initial project, `ai-homebase`, for the `openclaw` account so the cluster starts with in-cluster documentation about itself, its architecture, and its GitOps operating model.
- The startup posture is intentionally non-destructive: init and bootstrap logic may wait for dependencies or skip `occ`-driven reconciliation until the instance is installed, but the chart must not delete persisted runtime files such as `config/config.php` when `occ status` fails during a restart.
- The default mail path points Nextcloud at `platform-stack-postfix-relay:587` with no SMTP auth. The sender is built from `[mail]` in `bootstrap.local.toml`.
- The main Nextcloud container intentionally stays root for image bootstrap because the official entrypoint writes PHP config and synchronizes the application tree into the mounted PVC, while the cron worker runs as UID/GID `33` (`www-data`) because `php occ` and `cron.php` require the data-directory owner.
- Keep it on a dedicated hostname when exposing it through ingress.
- Backup and restore planning is mandatory before production use.

### Nextcloud MCP

- Dedicated MCP companion service for Nextcloud, pinned to `ghcr.io/cbcoutinho/nextcloud-mcp-server:0.65.3`.
- The standard stack runs it in `multi_user_basic` mode so OpenClaw can use one dedicated Nextcloud user while external ingress clients can authenticate with any normal Nextcloud user through Basic Auth.
- The chart points the MCP server at the in-cluster Nextcloud Service and exposes the MCP API on a separate hostname rooted at `/`.
- Baseline health checks use the upstream HTTP readiness path `/health/ready`.
- `scripts/bootstrap-secrets.sh` creates `openclaw-nextcloud-mcp-secrets` with `NEXTCLOUD_USERNAME=openclaw`, the dedicated password, and the precomputed `OPENCLAW_NEXTCLOUD_MCP_AUTH_HEADER`; OpenClaw consumes the auth header key, while the MCP pod itself stays in upstream `multi_user_basic` mode with `ENABLE_MULTI_USER_BASIC_AUTH=true`.
- OpenClaw now seeds one MCP bridge definition that tries the in-cluster service URL first and falls back to the ingress hostname, so the same server entry works from the gateway pod and from Docker sandboxes in the Incus VM. The bridge path is the shared runtime path `/opt/openclaw-runtime/mcp/mcp-http-bridge.mjs`, not an agent workspace path.
- The standard stack now pins the upstream app surface with `nextcloudMcp.enabledApps` and a small chart-managed launcher script. That workaround is necessary because the published upstream image currently wires `sharing` into the server but still rejects `--enable-app sharing` during CLI validation. The shipped enabled set remains `notes`, `webdav`, `sharing`, `tables`, and `calendar`; `Todos` come from the `calendar` surface through CalDAV tasks support.
- For `k3d`, `scripts/incus-vm-up.sh` configures the Incus VM plus its Docker containers to resolve the MCP ingress hostname to the Incus host listener address automatically.
- To add another MCP service to this stack, copy that same shape instead of inventing a new path: add the Kubernetes Service and ingress, make the ingress hostname resolve inside the Incus VM and its Docker containers, bootstrap any auth Secret refs, and add a gateway-level `openclaw.openclaw.mcp.servers.<name>` entry that points at `/opt/openclaw-runtime/mcp/mcp-http-bridge.mjs` with both an internal and external URL. Keep MCP bridges out of agent workspaces so every agent can share the same runtime path.

### Qdrant

- Shared vector-memory service for cross-agent RAG context and durable semantic recall.
- Enabled in baseline and both overlays; `k3d` uses a smaller PVC while `k3s` keeps production-sized storage.
- The chart pins the official `qdrant/qdrant:v1.17.1` image and exposes the standard HTTP API on port `6333`.
- The chart now points Qdrant storage, snapshots, and temp files at the mounted PVC explicitly and bootstraps writable permissions on that path. The container also runs as root so the upstream image can create its init marker under `/qdrant` on first boot, which prevents fresh `local-path` installs from crash-looping.

### Qdrant MCP

- Dedicated official Qdrant MCP companion service used by OpenClaw as a shared memory bridge.
- The chart now uses `python:3.12-slim` plus a startup venv bootstrap for `mcp-server-qdrant==0.8.0`, because the previously pinned GHCR image/tag was not pullable in a fresh cluster.
- Baseline wiring now follows the upstream default FastEmbed posture with `EMBEDDING_PROVIDER=fastembed` and `EMBEDDING_MODEL=BAAI/bge-base-en-v1.5`, so the service does not depend on an OpenAI key to start.
- The repo-managed defaults also set `TOOL_STORE_DESCRIPTION` and `TOOL_FIND_DESCRIPTION` so every bootstrapped agent sees the same Qdrant storage/query contract.
- The canonical memory schema now lives in [`docs/qdrant-memory-schema.md`](./qdrant-memory-schema.md) and is also seeded into the bootstrap Nextcloud project as `/Projects/ai-homebase/qdrant-memory-schema.md`.
- OpenClaw now seeds a gateway-level `mcp.servers.qdrant` entry via the shared `/opt/openclaw-runtime/mcp/mcp-http-bridge.mjs` bridge with internal and external URLs.

### Memgraph

- Shared graph-database service for long-term structured knowledge.
- The chart pins `memgraph/memgraph:3.8.1`, exposes Bolt on `7687` for in-cluster clients, and exposes the HTTP surface on `7444`.
- The Service now pins `ipFamilies: [IPv4]` with `ipFamilyPolicy: SingleStack` so sandbox DNS resolution does not drift onto unusable IPv6 answers for Bolt.
- The stack now also renders a repo-managed Memgraph bootstrap Job that waits for the database and loads an idempotent initial graph covering the user, core services, core agents, and the GitOps repositories.
- Archivist is the canonical graph steward. Other agents may still use Qdrant directly for ordinary memories, but durable graph curation, graph schema changes, and graph-linked memory grooming belong with archivist.
- The canonical graph schema now lives in [`docs/knowledge-graph-schema.md`](./knowledge-graph-schema.md) and is also seeded into the bootstrap Nextcloud project as `/Projects/ai-homebase/knowledge-graph-schema.md`.

### Memgraph Lab

- Dedicated UI companion for Memgraph.
- The chart pins `memgraph/lab:3.9.0`, serves the UI on port `3000`, and points its quick-connect defaults at the in-cluster Memgraph Service.
- Use Lab for visual inspection and exploration; archivist's canonical write path remains Cypher through `mgconsole`.

### How to add another MCP service to OpenClaw

1. Add the service chart and expose it with a dedicated in-cluster Service + ingress hostname.
2. Add host keys to `bootstrap.example.toml`, `scripts/bootstrap-config.py`, `charts/platform-stack/values*.yaml`, and docs so bootstrap rendering and overlays stay aligned.
3. Add any auth/env contracts via `existingSecret`, `envFromSecrets[]`, or `secretRefs[]` and keep them documented in this file.
4. Ensure the Incus VM bootstrap (`scripts/k3d-local-bootstrap.sh` and `scripts/k3s-homelab-sandbox-up.sh`) resolves the new hostname with `--resolve-host` so Docker sandboxes can reach the MCP ingress route.
5. Add one gateway-level `openclaw.openclaw.mcp.servers.<name>` entry using `/opt/openclaw-runtime/mcp/mcp-http-bridge.mjs` plus dual `--url` arguments (internal service URL first, ingress URL second).
6. Validate with lint + template commands for base, `k3d`, and `k3s` overlays, then confirm rendered OpenClaw config contains the new MCP server entry and expected URL placeholders.

### Gitea

- Source control service with persistent repositories.
- The bootstrap-managed default machine repos are the coder-owned GitOps repo for cluster definitions and the coder-owned sandbox-images repo for OpenClaw runtime image source.
- Disabled in the umbrella baseline, then enabled by both supported overlays with `k3d` sized down for local testing and `k3s` sized for the homelab.
- Baseline image defaults set `gitea.gitea.image.repository=gitea` and keep `rootless=true`, so the upstream chart resolves workloads to `docker.gitea.com/gitea:1.25.5-rootless` instead of the invalid `docker.gitea.com/docker.gitea.com/gitea` pull path.
- The `configure-gitea` init container must see the complete `[database]` section in `/data/gitea/conf/app.ini` before it can run migrations. The shipped defaults therefore load `gitea-config-secrets` through `gitea.gitea.gitea.additionalConfigFromEnvs` so the `init-app-ini` container writes the secret-backed `database`, `session`, `cache`, `queue`, and `global_lock` settings into `app.ini` before startup. The wrapper also injects a `preExtraInitContainers` SQL gate that waits until `psql` can connect as `gitea` to the `gitea` database, and it disables the upstream `valkey` and `valkey-cluster` subcharts so Gitea uses the umbrella chart's shared Redis instance instead of rendering a nested cache dependency.
- The umbrella chart now renders `shared-postgresql-bootstrap-job.yaml` whenever shared PostgreSQL is enabled and at least one of Gitea or Vaultwarden is enabled. That Job waits for `platform-stack-shared-postgresql:5432`, then idempotently reconciles the `gitea` and/or `vaultwarden` roles/databases against the live server during install/upgrade. The hook now runs with `restartPolicy: Never` plus `terminationMessagePolicy: FallbackToLogsOnError` so a failed attempt stays behind as a failed pod and Kubernetes preserves the tail of the container logs in the termination message for debugging.
- `scripts/bootstrap-secrets.sh` creates `gitea-config-secrets` with env-style `GITEA__...` keys plus `gitea-admin-secret` for the upstream chart's admin bootstrap. It reuses the existing `GITEA__database__PASSWD` and admin password values by default, so password rotation remains an explicit operator action unless you change the bootstrap config.
- Intended as an internal homelab service unless you deliberately expose it.
- Back up repositories and application state.

### Registry

- Stateful in-cluster Docker registry based on the official `registry:2` image.
- Disabled in the umbrella baseline, then enabled by both supported overlays with `k3d` sized down for local testing and `k3s` sized for the homelab.
- Exposed through ingress on its own hostname and kept on internal-CA HTTPS so coder-built images can target the same host naming model as the rest of the platform.
- `scripts/bootstrap-secrets.sh` creates `registry-auth-secret` with `username`, `password`, and `htpasswd`; reruns preserve the existing password by default when the bootstrap config leaves it empty.
- The seeded coder bootstrap uses those same credentials as the default push identity and tells coder to prefer image names of the form `<registry-host>/<namespace>/<app>:<tag>`.
- The regular and coder OpenClaw sandbox images now follow that rule by default and are expected to be published to the in-cluster registry before OpenClaw references new tags.
- Registry pushes and pulls require runtime trust, not just DNS reachability: the remote Docker sandbox runtime and the cluster node container runtime must trust the platform internal CA for the registry hostname.
- For sandboxed agents, hostname resolution follows the same `incus-vm-up.sh --resolve-host` path as OpenClaw, Nextcloud MCP, and Gitea.

### Vaultwarden

- Password-manager service deployed behind ingress with Vaultwarden's `DATABASE_URL` pointing at the shared PostgreSQL service, a dedicated `vaultwarden` database role, and a companion `VAULTWARDEN_DB_PASSWORD` secret key for bootstrap/wait logic.
- Disabled in the umbrella baseline, then enabled by both supported overlays with `k3d` sized down for local smoke tests and `k3s` sized for the homelab.
- The chart pins `ghcr.io/dani-garcia/vaultwarden:1.35.4`, mounts `/data` for persisted attachments/config, derives `DOMAIN` from the ingress hostname unless you override `vaultwarden.appConfig.domain`, and now enables ingress TLS through the internal cert-manager CA by default.
- `scripts/bootstrap-secrets.sh` creates the `vaultwarden-config-secrets` Secret with `DATABASE_URL` and `VAULTWARDEN_DB_PASSWORD`, and it also carries `ADMIN_TOKEN` when you set `vaultwarden_admin_token` in `bootstrap.local.toml`. The chart-managed shared PostgreSQL bootstrap Job uses the explicit password key to reconcile the live `vaultwarden` role/database without parsing the URL, and the Vaultwarden Deployment has an init container that waits until a direct SQL login succeeds. Re-running the bootstrap reuses the existing `VAULTWARDEN_DB_PASSWORD` and `ADMIN_TOKEN` values by default when the config leaves them empty. Vaultwarden initial-user creation is still not chart-managed in this repo; use the admin panel enabled by `ADMIN_TOKEN` to create users manually.
- The default mail path points Vaultwarden at `platform-stack-postfix-relay:587` with no SMTP auth. The bootstrap-generated values layer renders `SMTP_HOST`, `SMTP_PORT`, `SMTP_FROM`, `SMTP_FROM_NAME`, and `SMTP_SECURITY=off` from `[mail]`.
- Keep Vaultwarden on HTTPS externally; the app itself stays on HTTP behind ingress TLS termination, the TLS Secret is issued from the internal CA, and `DOMAIN` should match the external ingress URL so links, WebAuthn, and attachment downloads work correctly.

### Postfix relay

- Internal SMTP relay used by Nextcloud and Vaultwarden for outgoing mail.
- Disabled in the umbrella baseline and enabled in both supported overlays.
- The chart currently uses `boky/postfix:v4.4.0` and exposes only an in-cluster `ClusterIP` Service on port `587`.
- `[mail]` in `bootstrap.local.toml` sets the sender domain and SMTP hostname the relay presents to remote MTAs.
- The default posture is direct outbound delivery from the cluster to the internet. There is no app-level SMTP auth between cluster workloads and the relay.
- Deliverability depends on external DNS and reverse-DNS being set correctly for your owned domain and server IP.

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
