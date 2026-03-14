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
- `openclaw.agents.defaults.workspace`
- `openclaw.agents.list`

The container uses `OPENCLAW_CONFIG_PATH=/etc/openclaw/openclaw.json` while `OPENCLAW_STATE_DIR` remains aligned with the persistence mount path.

