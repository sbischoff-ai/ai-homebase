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
- Use `python3 scripts/bootstrap-config.py render-values --config bootstrap.local.toml` only as a generated bridge into Helm values for bootstrap-managed identities and optional OpenClaw defaults.
- Use the same `bootstrap.local.toml` for both `k3d` and `k3s`; cluster setup differs by target, but the stack bootstrap values and secret inputs stay shared.

Canonical global host keys include `global.hosts.paperlessNgx` for Paperless, `global.hosts.vaultwarden` for Vaultwarden, and `global.hosts.argocd` for Argo CD. Nextcloud also supports a second bootstrap-only hostname key, `hosts.nextcloud_public`, which feeds the public ingress host when the `k3s` overlay enables it.
Nextcloud MCP follows the same pattern: `global.hosts.nextcloudMcp` is the canonical values key, and bootstrap config uses `hosts.nextcloud_mcp`.
Mail delivery is also bootstrap-driven: `[mail]` in `bootstrap.local.toml` feeds `global.mail.*`, the Postfix relay hostname, and the default sender addresses used by Nextcloud and Vaultwarden.

## Layering model

### Layer A: shared defaults

Use `values.yaml` for safe, reusable defaults that should apply to both supported targets.

### Layer B: supported target overlays

Use exactly one supported overlay after `values.yaml`:

- `values-k3d.yaml`: local k3d smoke-test posture.
- `values-k3s.yaml`: productive homelab k3s posture.

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

- `openclaw.openclaw.agents.defaults.sandbox.*` renders the OpenClaw sandbox configuration directly into `openclaw.json`; the shipped defaults now emit an explicit `backend: docker` plus the `docker.*` runtime block.
- `openclaw.remoteDocker.*` is part of the standard OpenClaw posture for every supported target: keep it enabled and use overlays only to change the SSH endpoint, Secret name, or image details for a concrete environment.

OpenClaw now renders its Docker/browser sandbox JSON directly from chart values, and the standard `openclaw.remoteDocker.*` block wires `DOCKER_HOST`, `HOME`, injected Docker CLI tooling, and SSH material into the pod so Docker commands execute against the supported remote daemon over SSH.
When the standard Incus sandbox VM env file exists at `~/.local/state/ai-homebase/incus/openclaw-sandbox.env`, the shared bootstrap path now auto-discovers that concrete listener address for both `k3d` and `k3s` and writes an override values layer so later `bootstrap-stack.sh` reruns do not silently drift back to the profile-default hostname.
The shared OpenClaw defaults also pin `openclaw.openclaw.agents.defaults.workspace` to `/home/node/.openclaw/workspace` so the persisted path stays inside the PVC without duplicating `.openclaw`, while the `k3d` overlay keeps provider/search secret key mappings optional and local bootstrap fills in only the exported keys it forwards into `openclaw-app-secrets`.
For HTTP-backed MCP services, keep the OpenClaw-side definition under `openclaw.openclaw.mcp.servers.<name>`, but point `command` and `args` at a local bridge script rather than at the remote URL directly. The standard pattern is a bridge script persisted under `/home/node/.openclaw/workspace`, with dual `--url` arguments so the gateway pod can prefer the in-cluster Service URL while Docker sandboxes in the Incus VM fall back to the ingress hostname that resolves there.

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
- the dedicated Nextcloud MCP hostname
- outbound mail domain and SMTP hostname
- OpenClaw/search provider keys
- user-provided gateway/bootstrap secrets
- shared admin identity defaults
- per-service admin overrides
- GitOps handoff defaults such as the Argo CD hostname, GitOps repo name, branch, project, and robot user

Vaultwarden uses the bootstrap config for `ADMIN_TOKEN` rather than for first-user creation. That token enables the Vaultwarden admin panel so operators can create users manually after bootstrap.

The optional second-stage GitOps bootstrap reads the `[gitops]` section from `bootstrap.local.toml` and uses it to create an in-cluster Gitea repo plus the Argo CD project/application objects that point at that repo.

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
OpenClaw bootstrap config now also seeds `commands.mcp` and `mcp.servers.nextcloud` into `openclaw.json` on first start, and `scripts/bootstrap-secrets.sh` creates `openclaw-nextcloud-mcp-secrets` with the dedicated Nextcloud MCP credentials plus the precomputed Basic Auth header OpenClaw uses for that server definition.
When adding another MCP-backed service, treat the bridge, bootstrap config, auth Secret refs, ingress hostname, and Incus/Docker reachability as one unit. The bootstrap is only correct when the same MCP entry can work from both the gateway pod network and the remote Docker sandbox network.
Nextcloud now also exposes `nextcloud.bootstrapApps[]` for convergent app bootstrap through `occ`. Use that for repo-managed app requirements; keep `nextcloud.initialApps[]` only for cases that truly need the image entrypoint hook during first-time container initialization.
