# Helm chart notes

## Shared global values
`openclaw`, `nextcloud`, `gitea`, `paperless-ngx`, `infisical`, and `wg-easy` support a shared `global` block (with chart-specific host keys) for:

- `imagePullSecrets`
- `storageClass`
- `domain` and `hosts`
- `commonLabels`
- `podAnnotations`
- default scheduling controls (`nodeSelector`, `tolerations`, `affinity`)
- shared environment entries (`env`)

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
