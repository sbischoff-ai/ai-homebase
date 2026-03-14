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

For `openclaw`, `existingSecret` is used with explicit key mappings under `secretKeys.*` (including `secretKeys.gatewayToken` for gateway token auth).

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
