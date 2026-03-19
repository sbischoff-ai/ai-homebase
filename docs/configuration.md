# Configuration and values layering

This project uses Helm values layering to keep environment configuration explicit and reproducible.

## Values hierarchy (lowest to highest precedence)

1. `charts/platform-stack/values.yaml`
2. Target overlay (`values-k3d.yaml` or `values-k3s.yaml`)
3. Environment/team overlay file(s)
4. CLI overrides (`--set`, `--set-string`, `--set-file`)

Prefer files over `--set` for anything long-lived or shared.

Canonical global host keys for service ingress defaults are `global.hosts.paperlessNgx` and `global.hosts.wgEasy`.

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
- Intentional ingress exposure changes.

Do not encode persistent environment decisions only as CLI `--set` flags.

## Supported targeting model

The repository intentionally supports only:

- **k3d** for local testing.
- **k3s** for the productive homelab server.

Cloud-provider-specific deployment profiles and conditionals have been removed.

## Runtime defaults

The supported targets now split runtime posture by service:

- `openhands.runtime.mode` is fixed to `kubernetes`, and `openhands.kubernetes.*` renders the upstream `[kubernetes]` config block used for in-cluster runtime sandboxes.
- `openshell.*` configures the cluster-local OpenShell gateway service plus the endpoint/command values reused by OpenClaw overlays.
- `openclaw.openclaw.agents.defaults.sandbox.*` and `openclaw.openclaw.plugins.*` render the OpenClaw OpenShell sandbox/plugin configuration directly into `openclaw.json`.

OpenHands Kubernetes runtime defaults assume OpenHands itself is running inside the cluster and create per-session runtime resources in the configured namespace. The shipped OpenClaw defaults and overlays now target the OpenShell backend with session-scoped sandboxes rather than any host-Docker execution path.

## Values schema validation

Helm validates values against JSON schemas when running `helm lint`, `helm template`, and `helm install/upgrade` for charts that include `values.schema.json`.

Current schema coverage includes:

- `charts/platform-stack/values.schema.json`
- `charts/openclaw/values.schema.json`
- `charts/openshell/values.schema.json`
- `charts/openhands/values.schema.json`
- `charts/nextcloud/values.schema.json`
- `charts/paperless-ngx/values.schema.json`
- `charts/wg-easy/values.schema.json`
- `charts/infisical/values.schema.json`
- `charts/gitea/values.schema.json`

When adding or changing values keys, update both the chart values and schema in the same change.

## Global vs service-specific values

Use `global.*` for shared conventions such as domain names, storage defaults, image pull secrets, and common labels.

Use service-specific blocks when behavior must diverge, especially for:

- `openclaw.*` and `openhands.*`
- Secret references and env contracts
- Persistence and ingress controls
- OpenHands Kubernetes runtime settings and OpenClaw sandbox/plugin settings

## Toggle strategy for service composition

Canonical baseline defaults live in `charts/platform-stack/values.yaml`.
Treat service toggles as explicit environment decisions in `values-k3d.yaml`, `values-k3s.yaml`, or higher-precedence overlays.

Do not rely on ad-hoc CLI toggles for persistent environments.

## Secret layering guidance

Keep provider/bootstrap details out of shared target files when possible.
Commit only secret **references** in versioned overlays and generate the actual Kubernetes Secrets through your secret-management workflow.

## Example deployment command pattern

```bash
helm upgrade --install platform-stack charts/platform-stack \
  -n <namespace> \
  -f charts/platform-stack/values.yaml \
  -f charts/platform-stack/values-<target>.yaml
```
