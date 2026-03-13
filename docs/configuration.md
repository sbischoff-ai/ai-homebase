# Configuration model and value hierarchy

This repository centers on the umbrella chart `charts/platform-stack`, which composes OpenClaw, OpenHands, Nextcloud, Gitea, Paperless-ngx, Infisical, and wg-easy.

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

Ingress is controlled per component in `platform-stack` values:

- `openclaw.ingress.*` (public-by-default entrypoint)
- `openhands.ingress.*` (internal-only by default)
- `nextcloud.ingress.*`, `gitea.ingress.*`, `paperlessNgx.ingress.*` (optional public exposure)
- `infisical.ingress.*` (internal/admin-oriented)
- `wgEasy.ingress.*` (disabled by default; prefer private/admin-only exposure)

If you need ingress behavior changes (class, annotations, TLS, hosts), configure them under the service-specific `<service>.ingress.*` block in your selected profile/overrides.

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

### Current pattern (today): pre-created Kubernetes Secrets

Each service chart supports two secret-consumption patterns that reference existing Kubernetes Secrets:

- `existingSecret`: inject all keys from a single pre-created Secret via `envFrom.secretRef`.
- `secretRefs[]`: map individual Secret keys to explicit environment variables (`name`, `key`, `envVar`).

Naming convention used across chart comments and examples:

- Secret object names: `kebab-case` (for example `openclaw-app-secrets`).
- Secret data keys: `UPPER_SNAKE_CASE` (for example `OPENCLAW_API_TOKEN`).
- Mapped environment variables (`envVar`) should match the corresponding key name when possible.

### Target pattern (next): External Secrets + Infisical integration

Preferred flow:

- Define desired Kubernetes Secret targets under `externalSecrets.*` in `platform-stack` values.
- Use External Secrets Operator to sync from a provider (Azure Key Vault, AWS/GCP backends, or Infisical provider).
- Point service charts at generated target Secrets using `existingSecret` and/or `secretRefs[]`.

Infisical-specific target state:

- Use either the External Secrets Infisical provider (recommended for Kubernetes-native secret sync) or the Infisical operator/provider flow used by your cluster platform team.
- Keep provider auth material out of this repo and bind it via workload identity or separately-managed bootstrap Secrets.

Fallback (only where necessary):

- Pre-create Kubernetes Secrets out-of-band and reference them from service values.

Operational best practices:

- Rotate secrets centrally at the provider.
- Keep least-privilege identity boundaries between `openclaw` and `openhands`.
- Audit secret mappings during each environment promotion.
- Keep service-to-secret contracts documented in `docs/services.md`.

## Operational placeholders

Several keys are intentionally placeholders to keep this starter repository provider-agnostic:

- Queue provider details (`openhands.queue.*`).
- External secret store references (`externalSecrets.secretStoreRef`, mapping keys).
- Observability destinations (`observability.logging.destination`).
- Worker isolation settings (`workerIsolation.*`) are the operator-facing contract.

`workerIsolation.*` captures platform intent, while `openhands.runtimeClassName`, `openhands.nodeSelector`, `openhands.tolerations`, and `openhands.affinity` are the fields rendered into the OpenHands Deployment. Keep them aligned in environment overlays; if both are set, the `openhands.*` values take precedence at render time.

Treat these as required integration checkpoints before production rollout.
