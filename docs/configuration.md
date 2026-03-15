# Configuration and values layering

This project uses Helm values layering to keep environment configuration explicit and reproducible.

## Values hierarchy (lowest to highest precedence)

1. `charts/platform-stack/values.yaml`
2. Profile overlay (`values-dev.yaml`, `values-k3d.yaml`, `values-aks.yaml`, `values-prod.yaml`)
3. Environment/team overlay file(s) (`-f values-<profile>.<env>.yaml`)
4. CLI overrides (`--set`, `--set-string`, `--set-file`)

Prefer files over `--set` for anything long-lived or shared.

## Layering model

### Layer A: base chart defaults

Use `values.yaml` for safe, reusable defaults that should apply broadly.

### Layer B: profile overlays

Use profile files to encode environment class behavior:

- `values-dev.yaml`: low-cost local/dev defaults.
- `values-k3d.yaml`: k3d local-smoke overlay (loaded after `values-dev.yaml`).
- `values-aks.yaml`: AKS assumptions and cloud integration placeholders.
- `values-prod.yaml`: production-shaped resource/availability posture.

### Layer C: environment overlays

Create an overlay per real environment (for example `values-aks.prod-eu.yaml`) for:

- Real domains/hosts.
- Actual secret references.
- Service toggles for that environment.
- Storage class and sizing overrides.

### Layer D: runtime one-offs

Use CLI overrides only for temporary experiments, never as the only source of critical production config.

## Global vs service-specific values

Use `global.*` for shared conventions:

- Domain and default host naming patterns.
- Image pull secrets.
- Shared labels/annotations.
- Optional shared storage class default.

Use service-specific blocks when behavior must diverge:

- `openclaw.*` and `openhands.*` for core-plane differences.
- Optional service blocks for app-specific scaling/storage/ingress.
- Service-level secret references and env contracts.
- OpenClaw runtime configuration should be expressed via structured `openclaw.*` values (rendered to `openclaw.json`) rather than generic key/value config blobs.

## OpenHands persistence key migration

Canonical schema for OpenHands storage is `openhands.persistence.*`. All shipped platform profiles (`charts/platform-stack/values-*.yaml`) and storage examples now use `persistence.*` directly.

`openhands.workspace.*` remains a temporary compatibility alias that maps to the same behavior during the migration window.

Deprecation timeline: compatibility support for `openhands.workspace.*` is planned for removal in the first chart release after **2026-01-31**. Update any custom overlays to `openhands.persistence.*` before that release.

## Toggle strategy for optional services

Treat optional services as explicit decisions in each environment overlay:

- `nextcloud.enabled`
- `gitea.enabled`
- `paperlessNgx.enabled`
- `infisical.enabled`
- `wgEasy.enabled`

Do not rely on ad-hoc CLI toggles for persistent environments.

## Secret layering guidance

Current supported runtime contracts:

- `existingSecret`
- `secretKeys.gatewayToken` (OpenClaw gateway token key mapping)
- optional OpenClaw provider/search mappings under `secretKeys.*ApiKey`
- `envFromSecrets[]`
- `secretRefs[]`
- `secretEnv[]`

Recommended layering:

- Keep provider/bootstrap details out of chart profile files.
- Put only secret **references** in environment overlays.
- Generate target Kubernetes Secrets via External Secrets or controlled secret bootstrap processes.

## Example deployment command pattern

```bash
helm upgrade --install platform-stack charts/platform-stack \
  -n <namespace> \
  -f charts/platform-stack/values-<profile>.yaml \
  -f values-<profile>.<env>.yaml
```

## Intentional placeholders and production gaps

The configuration model leaves several items intentionally unresolved:

- Queue provider endpoints/credentials.
- External secret store IDs and key mappings.
- Final observability sinks and retention policy.
- Hardened network policy definitions.

Track these as mandatory production-readiness tasks, not optional cleanup.
