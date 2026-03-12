# Helm chart notes

## Shared global values
`openclaw` and `openhands` both support a shared `global` block for:

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

It also provides platform-level value placeholders for:

- ingress
- external secrets
- observability
- persistence
- autoscaling
- worker isolation
