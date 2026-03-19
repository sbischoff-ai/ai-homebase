# Architecture

`ai-homebase` is structured as a modular homelab platform:

1. **Core AI plane**: OpenClaw + OpenHands.
2. **Supporting personal-cloud services**: Nextcloud, Gitea, Paperless-ngx, Infisical, and wg-easy.

## Core AI plane

### OpenClaw

OpenClaw is the main assistant experience.
It owns the rendered sandbox configuration used by the supported target overlays.

### OpenHands

OpenHands provides the agentic coding UI/API.
In supported k3d and k3s deployments it acts as an in-cluster control plane and launches per-session Kubernetes runtime sandboxes inside the cluster.

## Supported targets

The repository intentionally supports only:

- `k3d` for local testing,
- `k3s` for the productive homelab deployment.

## Trust boundary

OpenClaw now ships with the `docker` sandbox backend value in the supported overlays, while OpenHands uses namespace-scoped in-cluster Kubernetes runtime sandboxes. OpenClaw Docker runtime integration is intentionally not part of this change, so no host Docker socket access or comparable runtime passthrough is configured here.
