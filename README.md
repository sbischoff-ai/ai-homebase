# ai-homebase

`ai-homebase` is a Helm-based homelab stack for running an AI control plane around OpenClaw and OpenHands, with optional services such as Nextcloud, Paperless-ngx, Gitea, and Infisical.

The repository intentionally supports two targets: `k3d` for local testing and `k3s` for the productive homelab server. Shared Helm values provide the baseline platform posture, while target overlays keep local and homelab deployment behavior explicit.

Use the root README as the orientation page, then move into the deployment entrypoint, full documentation map, configuration, services, and operator commands.

## Choose your path

- [Deployment entrypoint](./docs/deployment.md)
- [Full documentation map](./docs/README.md)
- [Understand configuration and values layering](./docs/configuration.md)
- [Review service toggles and contracts](./docs/services.md)
- [See operator commands](./docs/commands.md)

## Minimum bootstrap commands

Local `k3d` bootstrap:

```bash
export OPENAI_API_KEY="<your-openai-api-key>"
./scripts/k3d-local-bootstrap.sh --cluster-name ai-homebase-dev
```

Homelab `k3s` install:

```bash
helm dependency update charts/platform-stack
./scripts/install.sh --profile k3s
```
