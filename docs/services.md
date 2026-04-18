# Services Reference

This page records service toggles, ingress posture, persistence, and secret contracts. Configuration layering lives in [configuration.md](./configuration.md); OpenClaw runtime details live in [openclaw-runtime.md](./openclaw-runtime.md).

Baseline means `charts/platform-stack/values.yaml` before applying `values-k3d.yaml` or `values-k3s.yaml`.

## Service Matrix

| Service | Toggle | Baseline | `k3d` | `k3s` | Persistence | Secret contract |
| --- | --- | --- | --- | --- | --- | --- |
| cert-manager | `certManager.enabled` | Enabled | Enabled | Enabled | none | internal root CA Secret from `certManager.internalCA.rootCertificate.secretName`; export `ca.crt` only |
| OpenClaw | `openclaw.enabled` | Enabled | Enabled, local hostPath shared state | Enabled, `/var/lib/ai-homebase/openclaw-state` hostPath | `10Gi` baseline, `100Gi` hostPath budget on `k3s` | `openclaw-secrets`, `coder-credentials`, `reviewer-credentials`, `openclaw-remote-docker-ssh` |
| Argo CD | `argoCd.enabled` | Disabled for first apply | enabled by GitOps handoff | enabled by GitOps handoff | upstream defaults | repo Secret created by `scripts/bootstrap-gitops.sh` |
| Nextcloud | `nextcloud.enabled` | Enabled | `10Gi` local PVC | `1Ti` local-path PVC | primary shared user storage | `nextcloud-config-secrets` with admin, PostgreSQL, Redis values |
| Nextcloud MCP | `nextcloudMcp.enabled` | Enabled | Enabled | Enabled | none | `openclaw-nextcloud-mcp-secrets` |
| Qdrant | `qdrant.enabled` | Enabled | `10Gi` local PVC | `150Gi` local-path PVC | vector-memory storage | optional API key through `openclaw.qdrant.apiKeySecret` |
| Qdrant MCP | `qdrantMcp.enabled` | Enabled | Enabled | Enabled | none | no baseline secret; FastEmbed default |
| Memgraph | `memgraph.enabled` | Enabled | `10Gi` local PVC | `200Gi` local-path PVC | graph-memory storage | no baseline secret |
| Memgraph Lab | `memgraphLab.enabled` | Enabled | Enabled | Enabled | none | no baseline secret |
| Gitea | `gitea.enabled` | Disabled | Enabled, `5Gi` local PVC | Enabled, `150Gi` local-path PVC | repositories and attachments | `gitea-config-secrets`, `gitea-admin-secret` |
| Registry | `registry.enabled` | Disabled | Enabled, `5Gi` local PVC | Enabled, `100Gi` local-path PVC | image registry data | `registry-auth-secret` |
| Vaultwarden | `vaultwarden.enabled` | Disabled | Enabled, `5Gi` local PVC | Enabled, `20Gi` local-path PVC | app data and attachments | `vaultwarden-config-secrets` |
| Postfix relay | `postfixRelay.enabled` | Disabled | Enabled | Enabled | none | no Secret for default direct-delivery posture |
| Paperless-ngx | `paperlessNgx.enabled` | Disabled | Enabled, small local PVCs | Enabled, `50Gi` data, `300Gi` media, `20Gi` consume, `20Gi` export | document pipeline | `paperless-config-secrets` |
| Shared PostgreSQL | `sharedPostgresql.enabled` | Enabled | local-path PVC | `150Gi` local-path PVC | relational tier for apps | app passwords from bootstrap-managed service Secrets |
| Shared Redis | `sharedRedis.enabled` | Enabled | local-path PVC | `30Gi` local-path PVC | durable Redis state where apps expect it | `REDIS_HOST_PASSWORD` through app Secrets |

All supported ingress-enabled services use `ingress-nginx` with `ingressClassName: nginx` after target overlays are applied. The `k3s` prep script disables Traefik on fresh installs; do not add Traefik-only ingress assumptions to chart defaults.

## Core Notes

### cert-manager

The first bootstrap apply installs the controller stack with custom resources disabled, waits for cert-manager CRDs and webhook readiness, then reapplies with internal PKI resources enabled. The internal CA follows cert-manager's standard SelfSigned issuer to CA issuer pattern. Operators and bootstrap helpers may distribute the public `ca.crt`; never distribute the CA private key.

### OpenClaw

OpenClaw is the multi-agent gateway and runtime coordinator. The supported posture uses the repo-managed gateway image, remote Docker sandboxing through an Incus VM, shared host-backed OpenClaw state, seeded agents/workspaces, Qdrant MCP for semantic memory, Memgraph for structured graph memory, and Nextcloud MCP for shared project files. See [openclaw-runtime.md](./openclaw-runtime.md).
The shipped standing-agent model routing now spans OpenAI, Anthropic, and Google by default: `main` starts on Claude Sonnet 4.6, `coder` and `architect` start on GPT-5.4, `archivist` and `watchdog` stay on the smaller GPT-5.4 tiers, and `auditor` starts on Claude Opus 4.7 with cross-provider fallbacks for every agent. Operators using the repo defaults should provide `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, and `GEMINI_API_KEY`.
Heartbeat is intentionally explicit: `agents.defaults.heartbeat.every=0m` disables standing heartbeats for every agent unless a specific agent overrides it, `main` also keeps `heartbeat.includeSystemPromptSection=false`, and `watchdog` is the only standing agent with a nonzero scheduled heartbeat by default at `30m`. Runtime-created `HEARTBEAT.md` templates are not authoritative for scheduling; the rendered heartbeat interval is.
`coder-credentials` and `reviewer-credentials` now carry both the long-lived Gitea password and a bootstrap-managed tea API token for their agent identity. The password remains available for git/basic-auth and first-session fallback, while tea should authenticate from the seeded token by default.

### Argo CD

Argo CD is disabled in the initial shared values apply, then enabled by the integrated GitOps handoff. Bootstrap creates coder-owned in-cluster Gitea repositories, grants the shared reviewer account collaborator access, protects the default branch for the standard internal review flow, pushes a self-contained chart snapshot, registers the repo with Argo CD, triggers the initial sync, and waits for applications to become `Synced` and `Healthy`.

### Nextcloud And Nextcloud MCP

Nextcloud is the primary shared file and project-memory service. It uses shared PostgreSQL and shared Redis, starts with an empty skeleton directory, bootstraps required apps through `nextcloud.bootstrapApps[]`, and creates the dedicated `openclaw` user for MCP access.

Nextcloud MCP is exposed on its own hostname and runs in `multi_user_basic` mode. OpenClaw uses a bridge entry that tries the in-cluster Service URL first and the ingress URL second so the same MCP definition works from the gateway pod and Docker sandboxes.

### Qdrant, Qdrant MCP, Memgraph, And Memgraph Lab

Qdrant stores semantic memories through the Qdrant MCP service. The default Qdrant MCP runtime uses FastEmbed with `BAAI/bge-base-en-v1.5`, so it does not need an OpenAI key to start.

Memgraph stores durable structured knowledge and is bootstrapped with an idempotent initial graph. Archivist is the canonical graph steward. Memgraph Lab is the inspection UI; durable writes should still flow through archivist and `mgconsole`.

Memory schema details live in [qdrant-memory-schema.md](./qdrant-memory-schema.md) and [knowledge-graph-schema.md](./knowledge-graph-schema.md).

### Gitea, Registry, And GitOps

Gitea holds the GitOps repository and the sandbox image source repository. Bootstrap-side Gitea API and git operations use a local `kubectl port-forward` to the in-cluster Gitea service, so first install does not depend on the host trusting the internal ingress CA.
Gitea Actions support is enabled by default through `gitea.actions.enabled=true`. Bootstrap injects a global runner registration token into `gitea-config-secrets`, creates a second companion Incus VM just for Actions jobs, and starts a persistent `act_runner` container there in Docker-socket mode unless you explicitly disable that posture.
The default runner labels are intentionally explicit and non-GitHub-hosted: `linux-amd64` and `homebase-coder`, both mapped to the repo-managed `gitea-actions-job` image.
The local `k3d` smoke script now also creates a temporary `${release}-actions-smoke` repository in Gitea, uploads a tiny `.gitea/workflows/smoke.yaml`, and waits for that workflow to finish in the default Actions-enabled posture.

The registry stores OpenClaw sandbox images and future coder-built application images. Registry pulls and pushes require both DNS reachability and internal CA trust for the registry hostname in the cluster node runtime and remote Docker sandbox runtime.

### Vaultwarden

Vaultwarden uses shared PostgreSQL through `DATABASE_URL` and receives `ADMIN_TOKEN` from bootstrap config. Initial end-user creation is intentionally manual through the admin panel.

### Postfix Relay

Postfix relay is an internal SMTP relay for app mail. It reads sender domain and SMTP hostname from `[mail]` in `bootstrap.local.toml`. Production deliverability depends on external DNS, reverse DNS, and the target domain's mail posture.

### Paperless-ngx

Paperless uses shared PostgreSQL and shared Redis. The chart keeps its `data`, `media`, `consume`, and `export` PVCs separate so operators can size document storage independently from metadata and import/export staging.

## Secret Patterns

Supported chart patterns include `existingSecret`, `envFromSecrets[]`, `secretRefs[]`, and `secretEnv[]`. Prefer service-specific structured secret references when a chart provides them. Shared overlays should name stable Secrets; bootstrap scripts should create their contents during first install.

## Adding Another MCP-Backed Service

Add the service, Service, ingress hostname, bootstrap host key, auth Secret refs, Incus/Docker hostname resolution, and one OpenClaw gateway-level MCP entry together. The MCP entry should use `/opt/openclaw-runtime/mcp/mcp-http-bridge.mjs` with both an internal Service URL and an external ingress URL.
