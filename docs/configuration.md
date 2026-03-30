# Configuration and values layering

This project uses Helm values layering to keep environment configuration explicit and reproducible.

## Values hierarchy (lowest to highest precedence)

1. `charts/platform-stack/values.yaml`
2. Target overlay (`values-k3d.yaml` or `values-k3s.yaml`)
3. Environment/team overlay file(s)
4. CLI overrides (`--set`, `--set-string`, `--set-file`)

Prefer files over `--set` for anything long-lived or shared.

Incus sandbox VM assets intentionally live outside the Helm values hierarchy in `incus/` and `scripts/incus-vm-*.sh`. They are companion host/bootstrap resources rather than chart-managed Kubernetes objects, so keep their sizing, image, and access settings in those dedicated files/scripts instead of trying to encode them in chart values.

Local bootstrap operator input also lives outside the Helm values hierarchy:

- Commit `bootstrap.example.toml` as the template.
- Keep the real `bootstrap.local.toml` untracked in `.gitignore`.
- Use `python3 scripts/bootstrap-config.py render-values --config bootstrap.local.toml` only as a generated bridge into Helm values for bootstrap-managed identities and OpenClaw agent bootstrap defaults.
- Use the same `bootstrap.local.toml` for both `k3d` and `k3s`; cluster setup differs by target, but the stack bootstrap values and secret inputs stay shared.

Bootstrap-generated values now also seed one initial Nextcloud project for the cluster itself, `ai-homebase`, so the bootstrapped agents start with durable in-cluster documentation about the running system and its operating model.

Canonical global host keys include `global.hosts.paperlessNgx` for Paperless, `global.hosts.vaultwarden` for Vaultwarden, `global.hosts.registry` for the registry, and `global.hosts.argocd` for Argo CD. Nextcloud also supports a second bootstrap-only hostname key, `hosts.nextcloud_public`, which feeds the public ingress host when the `k3s` overlay enables it.
Nextcloud MCP follows the same pattern: `global.hosts.nextcloudMcp` is the canonical values key, and bootstrap config uses `hosts.nextcloud_mcp`.
Mail delivery is also bootstrap-driven: `[mail]` in `bootstrap.local.toml` feeds `global.mail.*`, the Postfix relay hostname, and the default sender addresses used by Nextcloud and Vaultwarden.

## Layering model

### Layer A: shared defaults

Use `values.yaml` for safe, reusable defaults that should apply to both supported targets.

### Layer B: supported target overlays

Use exactly one supported overlay after `values.yaml`:

- `values-k3d.yaml`: local k3d smoke-test posture.
- `values-k3s.yaml`: productive homelab k3s posture.

The current `k3s` overlay is tuned for a single-node host in the Hetzner A42U class: Ryzen 7 Pro 8700GE, 64 GB RAM, and about 3 TB of storage. That posture is expected to host the current stack plus leave capacity for future heavier services such as Qdrant, Memgraph, and additional coder-deployed applications.

### Layer C: environment overlays

Add extra overlays only for concrete environment decisions such as:

- Real domains and DNS names.
- Actual secret references.
- Storage sizing or class overrides.
- Environment-specific domains, TLS, or ingress-class details.

Do not encode persistent environment decisions only as CLI `--set` flags.

## Supported targeting model

The repository intentionally supports only:

- **k3d** for local testing.
- **k3s** for the productive homelab server.

Cloud-provider-specific deployment profiles and conditionals have been removed.

## Runtime defaults

The supported targets split runtime posture by service:

- `openclaw.openclaw.agents.defaults.sandbox.*` renders the shared OpenClaw sandbox configuration directly into `openclaw.json`; the shipped defaults now emit an explicit `backend: docker` plus the `docker.*` runtime block.
- `openclaw.remoteDocker.*` is part of the standard OpenClaw posture for every supported target: keep it enabled and use overlays only to change the SSH endpoint, Secret name, or image details for a concrete environment.

OpenClaw now renders its Docker/browser sandbox JSON directly from chart values, and the standard `openclaw.remoteDocker.*` block wires `DOCKER_HOST`, `HOME`, injected Docker CLI tooling, and SSH material into the pod so Docker commands execute against the supported remote daemon over SSH.
When the standard Incus sandbox VM env file exists at `~/.local/state/ai-homebase/incus/openclaw-sandbox.env`, the shared bootstrap path now auto-discovers that concrete listener address for both `k3d` and `k3s` and writes an override values layer so later `bootstrap-stack.sh` reruns do not silently drift back to the profile-default hostname.
The shared OpenClaw defaults pin `openclaw.openclaw.agents.defaults.workspace` to `/home/node/.openclaw/workspace`, then bootstrap explicit `agents.list[]` entries for `main`, `architect`, `coder`, and `watchdog`. The main agent stays on `/home/node/.openclaw/workspace`, while specialist agents use dedicated sibling workspaces such as `/home/node/.openclaw/workspace-architect`, `/home/node/.openclaw/workspace-coder`, and `/home/node/.openclaw/workspace-watchdog`.
For remote Docker sandboxing, the important constraint is broader than the workspace paths alone: the gateway pod and the remote Docker host must see the same OpenClaw state tree at the same absolute path, because OpenClaw binds sandbox workspaces from `/home/node/.openclaw/sandboxes/...`. The supported overlays now mount a shared host directory into the pod and into the Incus VM so sandbox `/workspace` resolves to the same durable state that the gateway uses for agent workspaces and skills.
The same Incus companion path also owns hostname reachability for sandboxed agents. Any ingress hostname the sandbox must call, including the OpenClaw gateway hostname for `sessions_send` traffic, should flow through the shared `--resolve-host` mechanism so the VM and its Docker containers resolve it to the Incus host listener address instead of `127.0.0.1` or public DNS.
Bootstrap-local agent model selection now lives in `bootstrap.local.toml` under `[openclaw.agents.main]`, `[openclaw.agents.architect]`, `[openclaw.agents.coder]`, and `[openclaw.agents.watchdog]`; the generated OpenClaw config seeds those models into `agents.defaults.models`, assigns the configured model to each explicit agent, keeps the shared default sandbox mode at `non-main`, forces only `coder` to `sandbox.mode = "all"`, and forces `watchdog` to `sandbox.mode = "off"` so it always runs in the gateway.
The shipped multi-agent posture follows the standard orchestrator-plus-specialists pattern: `main` is the user-facing coordinator, `architect` handles planning/design/specification, `coder` owns code/repo/GitOps execution, and `watchdog` owns low-cost heartbeat-driven monitoring, polling, and triage. `tools.agentToAgent` is enabled with `tools.sessions.visibility=all` so delegation sessions stay visible to every agent. Because MCP-injected tools are not reliably hidden by per-agent deny rules, the stack now relies on seeded workspace instructions instead: all agents can see the shared Nextcloud tool surface, while `AGENTS.md` and `TOOLS.md` define ownership boundaries, note-tagging conventions, and durable-storage habits. `main` also gets a seeded `BOOTSTRAP.md` so the normal first-use bootstrap conversation still runs and starts the standing specialist sessions, including `watchdog`.
For HTTP-backed MCP services, keep the OpenClaw-side definition under `openclaw.openclaw.mcp.servers.<name>`, but point `command` and `args` at a shared runtime bridge path rather than at the remote URL directly. The standard path is `/opt/openclaw-runtime/mcp/mcp-http-bridge.mjs`, with dual `--url` arguments so the gateway pod can prefer the in-cluster Service URL while Docker sandboxes in the Incus VM fall back to the ingress hostname that resolves there.

For the current single-node `k3s` target, resource planning should also account for the fact that the OpenClaw remote Docker sandbox VM is outside Kubernetes but still on the same machine. Leave host-level headroom for that VM and for sandboxed coder workloads instead of assigning every CPU core and every GiB of RAM to Kubernetes requests alone.

## Values schema validation

Helm validates values against JSON schemas when running `helm lint`, `helm template`, and `helm install/upgrade` for charts that include `values.schema.json`.

Current schema coverage includes:

- `charts/platform-stack/values.schema.json`
- `charts/openclaw/values.schema.json`
- `charts/nextcloud/values.schema.json`
- `charts/paperless-ngx/values.schema.json`
- `charts/gitea/values.schema.json`
- `charts/vaultwarden/values.schema.json`

When adding or changing values keys, update both the chart values and schema in the same change.

## Global vs service-specific values

Use `global.*` for shared conventions such as domain names, storage defaults, image pull secrets, and common labels.

Use service-specific blocks when behavior must diverge, especially for:

- `certManager.*` umbrella toggles and PKI resources
- `cert-manager.*` upstream subchart values passed through the umbrella chart
- `openclaw.*`
- `sharedPostgresql.bootstrap.*` for the chart-managed live PostgreSQL reconciliation Job image
- `gitea.gitea.*` upstream wrapper values, including disabling upstream `valkey` / `valkey-cluster` in favor of the umbrella `sharedRedis` service
- Secret references and env contracts
- Persistence and ingress controls
- OpenClaw sandbox settings

`certManager.resourcesEnabled` separately controls whether the umbrella chart renders `cert-manager.io/v1` resources at all. Keep it `false` for first-install/bootstrap renders where the CRDs may not exist yet, then enable it after the cert-manager controller stack is ready.

Use the canonical lowercase `cert-manager:` top-level key in umbrella values files for upstream chart settings such as `crds.enabled` and `crds.keep`; reserve `certManager:` for umbrella-specific enablement, namespace fallback, and internal PKI resources.

`certManager.internalCA.*` controls the internal PKI bootstrap resources (SelfSigned bootstrap issuer, root CA certificate Secret, and CA ClusterIssuer), while the OpenClaw ingress hostname and TLS Secret remain driven by `openclaw.ingress.hosts[*]` and `openclaw.ingress.tls[*]`. Keep those values aligned so the cert-manager `Certificate` and the rendered ingress reference the same hostname and Secret.

For reverse-proxied OpenClaw deployments, set `openclaw.openclaw.gateway.trustedProxies` to the ingress-controller source CIDRs or IPs for the active target overlay. Keep `openclaw.openclaw.gateway.controlUi.allowedOrigins` on the external HTTPS origin, while OpenClaw itself continues serving plain HTTP behind the ingress controller.

## Toggle strategy for service composition

Canonical baseline defaults live in `charts/platform-stack/values.yaml`.
Treat service toggles as explicit environment decisions in `values-k3d.yaml`, `values-k3s.yaml`, or higher-precedence overlays.

Do not rely on ad-hoc CLI toggles for persistent environments.

## Secret layering guidance

Keep provider/bootstrap details out of shared target files when possible.
Commit only secret **references** in versioned overlays and generate the actual Kubernetes Secrets through your secret-management workflow.

For local or operator-managed bootstrap, treat `bootstrap.local.toml` as the canonical source for:

- service hostnames
- registry hostname and registry auth defaults
- the dedicated Nextcloud MCP hostname
- outbound mail domain and SMTP hostname
- OpenClaw/search provider keys
- OpenClaw per-agent model selections under `[openclaw.agents.main]`, `[openclaw.agents.architect]`, `[openclaw.agents.coder]`, and `[openclaw.agents.watchdog]`
- user-provided gateway/bootstrap secrets
- shared admin identity defaults
- per-service admin overrides
- registry auth credentials under `[services.registry.auth]`
- GitOps handoff defaults such as the Argo CD hostname, GitOps repo name, branch, project, and coder-owned Gitea execution identity

Vaultwarden uses the bootstrap config for `ADMIN_TOKEN` rather than for first-user creation. That token enables the Vaultwarden admin panel so operators can create users manually after bootstrap.

The optional second-stage GitOps bootstrap reads the `[gitops]` section plus `[openclaw.agents.coder.gitea]` from `bootstrap.local.toml` and uses them to create an in-cluster Gitea repo plus the Argo CD project/application objects that point at that repo.

If a password/secret field is left empty in the config, the bootstrap secret scripts keep the existing in-cluster value when present or generate a new one.

The mail section currently expects:

- `mail.domain`: sender domain used by the Postfix relay and application mail config
- `mail.smtp_host`: public SMTP hostname the relay identifies as, for example `smtp.example.com`
- `mail.from_localpart`: sender local-part used for app mail, default `noreply`
- `mail.from_name`: display name used by Vaultwarden mail, default `ai-homebase`

## Example deployment command pattern

```bash
helm upgrade --install platform-stack charts/platform-stack   -n <namespace>   -f charts/platform-stack/values.yaml   -f charts/platform-stack/values-<target>.yaml
```


Shared PostgreSQL no longer relies on a persistent `/docker-entrypoint-initdb.d` payload for Gitea/Vaultwarden/Nextcloud/Paperless role creation. Instead, the umbrella chart renders a live reconciliation Job when `sharedPostgresql.enabled=true` and any of `gitea.enabled=true`, `vaultwarden.enabled=true`, `nextcloud.enabled=true`, or `paperlessNgx.enabled=true`; the corresponding workloads use dedicated PostgreSQL roles/databases, and Gitea/Vaultwarden/Paperless explicitly gate startup on direct SQL connectivity before app startup.
OpenClaw bootstrap config now also seeds explicit `main`, `architect`, `coder`, and `watchdog` agents, `tools.agentToAgent`, plus `commands.mcp` and `mcp.servers.nextcloud` into `openclaw.json` on first start. It also seeds per-agent workspace files into the durable OpenClaw state directory on first run so specialists start with their role instructions immediately while `main` still retains a first-use bootstrap ritual through a seeded `BOOTSTRAP.md`. `coder` also gets a dedicated sandbox image override, `watchdog` is pinned to unsandboxed gateway execution for low-cost heartbeat work, and coder's Gitea/GitOps/registry workflow guidance now lives directly in `TOOLS.md` so it survives the current sandbox skill-staging limitations. `scripts/bootstrap-secrets.sh` still creates `openclaw-nextcloud-mcp-secrets` with the dedicated Nextcloud MCP credentials plus the precomputed Basic Auth header OpenClaw uses for that server definition.
When adding another MCP-backed service, treat the bridge, bootstrap config, auth Secret refs, ingress hostname, and Incus/Docker reachability as one unit. Keep the bridge outside any agent workspace and ensure the same absolute path exists in both the gateway runtime and the sandbox runtime; the bootstrap is only correct when the same MCP entry can work from both the gateway pod network and the remote Docker sandbox network.
Nextcloud now also exposes `nextcloud.bootstrapApps[]` for convergent app bootstrap through `occ`. Use that for repo-managed app requirements; keep `nextcloud.initialApps[]` only for cases that truly need the image entrypoint hook during first-time container initialization.
