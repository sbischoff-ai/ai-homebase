# Helm chart notes

## Shared global values
`openclaw`, `openhands`, `nextcloud`, `gitea`, `paperless-ngx`, `infisical`, and `wg-easy` support a shared `global` block (with chart-specific host keys) for:

- `imagePullSecrets`
- `storageClass`
- `domain` and `hosts`
- `commonLabels`
- `podAnnotations`
- default scheduling controls (`nodeSelector`, `tolerations`, `affinity`)
- shared environment entries (`env`)

Most service charts also expose `existingSecret` and `secretRefs[]` to consume credentials from pre-created Kubernetes Secrets using standardized key naming conventions.

`infisical` now follows upstream standalone chart value paths (`infisical.*`, `ingress.*`, `postgresql.*`, `redis.*`) and uses `infisical.kubeSecretRef` for bootstrap/runtime credentials.

For `openclaw`, `existingSecret` is used with explicit key mappings under `secretKeys.*` (including `secretKeys.gatewayToken` for gateway token auth).

## Gitea chart source
`charts/gitea` is a local wrapper pinned to the official upstream Helm chart (`repository: https://dl.gitea.com/charts/`, `version: 12.5.0`). The `platform-stack` umbrella continues to depend on the local `file://../gitea` wrapper so umbrella dependency builds remain local/offline-friendly while still pinning upstream Gitea in one place.

When chart metadata changes, refresh lock/vendor state with:

```bash
helm dependency update charts/gitea
helm dependency update charts/platform-stack
```

### Gitea probe wiring note
The wrapper currently retains local templates (including `templates/statefulset.yaml`) for platform-level wiring. Probe values are declared in `charts/gitea/values.yaml` under `probes.liveness` and `probes.readiness` and wired into rendered pod probes with `httpGet` on port `http`. Defaults are set to `/api/healthz`.

Operational expectation: `GET /api/healthz` returns **HTTP 200** for healthy pods. If wrapper templates are further reduced during migration to official-chart-only rendering, re-verify probe values are still present in rendered manifests (not just values declarations).

## platform-stack composition
`platform-stack` is an umbrella chart with dependency toggles:

- `openclaw.enabled`
- `openhands.enabled`
- `nextcloud.enabled`
- `gitea.enabled`
- `paperlessNgx.enabled`
- `infisical.enabled`
- `wgEasy.enabled`

It also provides platform-level value placeholders for:

- ingress
- external secrets
- observability
- persistence
- autoscaling
- worker isolation


## Network policy placeholders
Internal/admin-oriented charts expose optional `networkPolicy.*` values and templates:

- `openclaw.networkPolicy.*`
- `openhands.networkPolicy.*`
- `infisical.networkPolicy.*`
- `wgEasy.networkPolicy.*`

## Snapshot (golden manifest) policy

This repository uses snapshot-based tests for umbrella chart rendering under `tests/golden/`.

- Profiles covered:
  - `values` (`charts/platform-stack/values.yaml`)
  - `values-dev` (`charts/platform-stack/values-dev.yaml`)
  - `values-dev-k3d` (`values-dev.yaml` layered with `values-k3d.yaml`)
  - `values-aks` (`charts/platform-stack/values-aks.yaml`)
  - `values-prod` (`charts/platform-stack/values-prod.yaml`)
- Golden files are generated with `scripts/ci/update_golden.sh`.
- Verification runs with `scripts/ci/check_golden.sh`, which re-renders and diffs against committed fixtures.

To reduce flakiness, snapshots are normalized and scoped to stable Kubernetes resource kinds (`Deployment`, `StatefulSet`, `Service`, `Ingress`, `ConfigMap`, and related core workload/service objects). Volatile metadata fields and dynamic Helm-release annotations are removed during normalization.

Use this workflow when you intentionally change rendering output:

```bash
helm dependency build charts/platform-stack
scripts/ci/update_golden.sh
scripts/ci/check_golden.sh
```

If `check_golden.sh` fails unexpectedly, inspect the diff first; only update fixtures when manifest changes are intentional.

## OpenClaw dedicated config file
The `openclaw` chart renders an `openclaw.json` ConfigMap entry from structured `openclaw.*` values and mounts it to `/etc/openclaw/openclaw.json` in the pod.

Primary value paths:

- `openclaw.gateway.mode`
- `openclaw.gateway.bind`
- `openclaw.gateway.port`
- `openclaw.gateway.auth.mode`
- `openclaw.gateway.controlUi.enabled`
- `openclaw.gateway.controlUi.allowedOrigins`
- `existingSecret`
- `secretKeys.gatewayToken`
- optional `secretKeys.*ApiKey` provider/search mappings
- `openclaw.agents.defaults.workspace`
- `openclaw.agents.list`
- `ingress.enabled` (disabled by default; enable only when intentionally exposing via internal/private or public ingress)
- `ingress.defaultHost` (optional fallback before `global.hosts.openclaw`)

The container uses `OPENCLAW_CONFIG_PATH=/etc/openclaw/openclaw.json` while `OPENCLAW_STATE_DIR` remains aligned with the persistence mount path.

Default exposure posture for OpenClaw is internal-only: `Service` type `ClusterIP` with no ingress enabled. Recommended access is over VPN/private networking, for example `http://openclaw.default.svc.cluster.local:18789`.

When `openclaw.gateway.auth.mode` is `token`, chart rendering fails fast unless `existingSecret` and `secretKeys.gatewayToken` are set. The rendered config references `${OPENCLAW_GATEWAY_TOKEN}` and expects the env var to be injected from the configured secret key.

When `openclaw.gateway.bind` is non-loopback (for example `lan`) and `openclaw.gateway.controlUi.enabled=true`, chart rendering also requires a non-empty `openclaw.gateway.controlUi.allowedOrigins` list.

When ingress is enabled, ensure each `ingress.hosts[*].host` has a matching exact public origin (scheme + host) in `openclaw.gateway.controlUi.allowedOrigins`.

## OpenHands ingress values

OpenHands keeps `service.type: ClusterIP` by default.

Baseline OpenHands deployment defaults in this repo:

- `image.repository: docker.openhands.dev/openhands/openhands`
- `image.tag: 1.5` (chart `appVersion` is also `1.5`)
- `service.port: 3000`
- `service.targetPort: 3000`
- `runtime.mode: ""` (optional neutral runtime mode passed into the app as `RUNTIME_MODE`)
- `runtime.className: ""` (optional Kubernetes RuntimeClass selector; portable scheduling control)
- `agentServer.image.repository: ghcr.io/openhands/agent-server`
- `agentServer.image.tag: 1.12.0-python`

OpenHands also renders the following env vars by default:

- `AGENT_SERVER_IMAGE_REPOSITORY` from `agentServer.image.repository`
- `AGENT_SERVER_IMAGE_TAG` from `agentServer.image.tag`
- `RUNTIME_MODE` from `runtime.mode`

Ingress controls are available under `openhands.ingress.*`:

- `ingress.enabled`
- `ingress.hostName` (preferred single host entry)
- `ingress.ingressClassName`
- `ingress.annotations`
- `ingress.tls`

Use internal/VPN hostnames for admin/internal deployments (for example `openhands.vpn.homebase.internal`) and pair them with an internal ingress class.

OpenHands persistence controls are available under `openhands.persistence.*`:

- `persistence.enabled` (default `true`)
- `persistence.mountPath` (default `/.openhands`)
- `persistence.size`
- `persistence.storageClass` (falls back to `global.storageClass` when empty)
- `persistence.accessModes`
- `persistence.existingClaim`
- `persistence.annotations`

`openhands.workspace.*` is deprecated and retained only as a temporary compatibility alias for `openhands.persistence.*`. Platform overlays and examples in this repository now use `openhands.persistence.*`.

Deprecation timeline: `openhands.workspace.*` will be removed in the first chart release after **2026-01-31**. Migrate all overlays to `openhands.persistence.*` before that date to avoid breaking upgrades.

OpenHands secret/env controls follow the shared conventions and can be mixed safely:

- `existingSecret` and `envFromSecrets[]` for bulk `envFrom` secret imports.
- `env[]` for plain env values.
- `secretRefs[]` for explicit `{name, key, envVar}` mappings.
- `secretEnv[]` for explicit `{name, secretName, key, optional}` mappings rendered as `valueFrom.secretKeyRef`.

OpenHands-focused secret examples:

- Required/expected: `LLM_API_KEY`
- Optional: `LLM_MODEL`, `OH_WEB_URL`
- Optional/future: provider/git credentials such as `OPENAI_API_KEY`, `GITHUB_TOKEN`

For Infisical integration, sync secret material into Kubernetes Secret names (for example `openhands-app-secrets`) and point OpenHands values (`existingSecret`, `envFromSecrets`, `secretRefs`, `secretEnv`) at those Secret names. This matches the OpenClaw-style contract of referencing Kubernetes Secrets from chart values.
