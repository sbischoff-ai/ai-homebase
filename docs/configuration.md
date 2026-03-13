# Configuration model and value hierarchy

This repository centers on the umbrella chart `charts/platform-stack`, which composes `openclaw` and `openhands`.

## Value hierarchy

When Helm renders templates, values are resolved from most generic to most specific:

1. **Chart defaults** (`charts/platform-stack/values.yaml`).
2. **Environment/profile overlay** (`values-dev.yaml`, `values-aks.yaml`, `values-prod.yaml`).
3. **User/team override files** (for example `-f values.<env>.local.yaml`).
4. **CLI `--set` / `--set-string` overrides** (highest precedence).

Within chart values, intent is organized as:

- `global.*` for shared defaults consumed across components.
- `openclaw.*` for control-plane-only settings.
- `openhands.*` for execution-plane-only settings.
- Platform integration placeholders (`externalSecrets`, `observability`, `persistence`, `autoscaling`, `workerIsolation`) for stack-level operations.


## Ingress source of truth

The authoritative ingress toggle for platform-stack is `openclaw.ingress.enabled`.

- Set `openclaw.ingress.enabled=true` to render the OpenClaw ingress resource.
- Set `openclaw.ingress.enabled=false` to disable ingress creation.
- The former top-level `ingress.enabled` in platform-stack values was removed to avoid conflicting intent.

If you need ingress behavior changes (class, annotations, TLS, hosts), configure them under `openclaw.ingress.*` in your selected profile/overrides.

## `global` vs component-specific values

Use `global` for values that should stay consistent across both services:

- host/domain conventions
- common labels/annotations
- image pull secrets
- baseline scheduling controls
- shared environment entries

Use component-specific values when behavior diverges between planes:

- resource requests/limits
- autoscaling targets
- service exposure
- persistence/workspace specifics
- queue/runtime behavior (`openhands`)

Prefer explicit component overrides rather than overloading `global` when requirements differ.

## Environment overlays

Current profiles:

- `values-dev.yaml`: local/dev minimal profile.
- `values-aks.yaml`: AKS-oriented profile with workload identity and external secret placeholders.
- `values-prod.yaml`: production-shaped profile with stronger availability/security defaults.

Recommended usage pattern:

- Keep profile files as reusable baselines.
- Add thin environment-specific overlays outside the chart to hold real hostnames, image tags, and secret references.
- Keep one deployment command contract across environments:

```bash
helm upgrade --install platform-stack charts/platform-stack \
  -n <namespace> \
  -f charts/platform-stack/values-<profile>.yaml \
  -f <team-or-env-override>.yaml
```

## Secrets strategy

Do not commit live credentials to this repository.

Preferred flow:

- Use `externalSecrets.*` mappings to define desired Kubernetes Secret targets.
- Back the mappings with an external provider (for example Azure Key Vault in AKS).
- Keep placeholders in version-controlled values, and resolve real secret identifiers per environment.

Fallback (only where necessary):

- Pre-create Kubernetes Secrets out-of-band and reference them from component env/config hooks.

Operational best practices:

- Rotate secrets centrally at the provider.
- Keep least-privilege identity boundaries between `openclaw` and `openhands`.
- Audit secret mappings during each environment promotion.

## Operational placeholders

Several keys are intentionally placeholders to keep this starter repository provider-agnostic:

- Queue provider details (`openhands.queue.*`).
- External secret store references (`externalSecrets.secretStoreRef`, mapping keys).
- Observability destinations (`observability.logging.destination`).
- Worker isolation settings (`workerIsolation.*`, runtime class and node placement).

Treat these as required integration checkpoints before production rollout.
