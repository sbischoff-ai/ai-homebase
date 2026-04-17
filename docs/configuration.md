# Configuration And Values Layering

This project keeps durable environment decisions in files so a first-run bootstrap can be repeated from source without reconstructing CLI history.

## Values Precedence

Lowest to highest precedence:

1. `charts/platform-stack/values.yaml`
2. exactly one target overlay: `charts/platform-stack/values-k3d.yaml` or `charts/platform-stack/values-k3s.yaml`
3. optional operator/environment overlays
4. temporary CLI overrides such as `--set`

Use files for anything that should survive a terminal session. Do not encode persistent hostnames, storage classes, resource sizing, service toggles, or secret references only as CLI flags.

## Supported Targets

The repository supports two deployment profiles:

- `k3d`: local full-stack validation and smoke testing.
- `k3s`: the long-running single-node homelab target.

Both profiles use `ingress-nginx` and the `nginx` ingress class. The `k3s` host-prep script disables the bundled Traefik add-on on fresh installs so rendered ingress classes and cluster ingress behavior stay aligned.

The `k3s` overlay is sized for the current Hetzner A42U-class target: Ryzen 7 Pro 8700GE, 64 GB RAM, and roughly 3 TB storage. See [storage.md](./storage.md) for the current rendered storage and request summary.

## Bootstrap Config

`bootstrap.local.toml` is the operator input for both targets. It is intentionally untracked.

Use this flow:

```bash
cp bootstrap.example.toml bootstrap.local.toml
python3 scripts/bootstrap-config.py validate --config bootstrap.local.toml
```

`bootstrap.local.toml` provides:

- service hostnames and optional public Nextcloud hostname
- `[mail]` sender domain, SMTP hostname, sender local-part, and display name
- provider/search API keys
- shared admin identity and service-specific admin overrides
- Gitea Actions runner bootstrap settings under `[services.gitea.actions]` with Actions enabled by default
- OpenClaw gateway token and agent model selections
- registry credentials, coder Gitea defaults, and the shared reviewer Gitea identity for architect and auditor
- first-run application secrets when the operator wants explicit values

`scripts/bootstrap-config.py render-values` turns that file into a generated Helm values layer during bootstrap. Treat the generated layer as a bridge from operator input into Helm, not as the long-term source of truth.

## What Belongs Where

Use `charts/platform-stack/values.yaml` for reusable stack defaults that should apply to both supported targets.

Use `values-k3d.yaml` or `values-k3s.yaml` when behavior must differ by target, including ingress hosts, storage classes, local storage sizing, resource requests, image pull posture, and service enablement.

Use an operator overlay for real environment decisions that are neither safe shared defaults nor target-generic defaults, such as production hostnames, certificate issuer overrides, or larger service-specific storage.

Use `incus/` and `scripts/incus-vm-*.sh` for the OpenClaw remote Docker sandbox VM. The VM is a companion host/bootstrap resource, not a Helm-managed Kubernetes object.

## Values And Secrets

Commit secret references, not secret values. The first-run path creates bootstrap-managed Kubernetes Secrets through `scripts/bootstrap-secrets.sh`; operators can later move long-lived secret management to encrypted manifests under [`secrets/`](../secrets/).

Common stable Secret names include:

- `openclaw-secrets`
- `coder-credentials`
- `reviewer-credentials`
- `openclaw-remote-docker-ssh`
- `nextcloud-config-secrets`
- `openclaw-nextcloud-mcp-secrets`
- `gitea-config-secrets`
- `registry-auth-secret`
- `vaultwarden-config-secrets`
- `paperless-config-secrets`

If a password field is empty in `bootstrap.local.toml`, bootstrap keeps an existing in-cluster value when one exists or generates a fresh value for a first install.

## Chart Key Conventions

Use `global.*` for shared conventions such as hostnames, storage defaults, common labels, and image pull secrets.

Use service blocks for service-specific behavior:

- `certManager.*` for umbrella-owned cert-manager enablement and internal PKI resources
- `cert-manager.*` for upstream cert-manager subchart values
- `openclaw.*` for gateway, agent, workspace, sandbox, and MCP runtime values
- `nextcloud.*`, `gitea.*`, `paperlessNgx.*`, and other service keys for service-local ingress, persistence, resources, secret refs, and bootstrap-owned companion settings such as `gitea.actions.*`

Use the canonical host keys under `global.hosts.*`, including `paperlessNgx`, `vaultwarden`, `registry`, `argocd`, `qdrant`, `qdrantMcp`, `memgraph`, `memgraphLab`, and `nextcloudMcp`. Bootstrap config uses snake_case TOML names where appropriate, for example `hosts.nextcloud_mcp`.

`certManager.resourcesEnabled=false` is intentional for the first Helm apply because the cert-manager CRDs may not exist yet. `scripts/bootstrap-stack.sh` installs cert-manager first, waits for the CRDs and webhook, then reapplies with cert-manager resources enabled.

## Schema Validation

Helm validates chart values through JSON schemas when charts provide them. Current schema coverage includes:

- `charts/platform-stack/values.schema.json`
- `charts/openclaw/values.schema.json`
- `charts/nextcloud/values.schema.json`
- `charts/paperless-ngx/values.schema.json`
- `charts/gitea/values.schema.json`
- `charts/vaultwarden/values.schema.json`

When adding, removing, or renaming a value key, update the source values, schema, docs, and any affected bootstrap config generation together.

## OpenClaw Runtime

OpenClaw has enough runtime-specific contract to deserve its own page. See [openclaw-runtime.md](./openclaw-runtime.md) for the repo-managed gateway image, remote Docker sandbox, shared state path, internal CA bundle, MCP bridge, seeded agents, and workspace layout.
