# Architecture

`ai-homebase` is structured as a modular homelab platform:

1. **Core AI plane**: OpenClaw + OpenHands.
2. **Supporting personal-cloud services**: Nextcloud, Gitea, Paperless-ngx, Infisical, and wg-easy.

## Core AI plane

### OpenClaw

OpenClaw is the main assistant experience.
It also owns the rendered sandbox configuration used for Docker-backed agent execution in supported targets.

### OpenHands

OpenHands provides the agentic coding UI/API.
In supported k3d and k3s deployments it mounts the host Docker socket so in-cluster execution follows the documented Docker-backed runtime model.

## Supported targets

The repository intentionally supports only:

- `k3d` for local testing,
- `k3s` for the productive homelab deployment.

## Trust boundary

Docker-socket-based sandboxing is treated as part of the homelab design for these targets.
That improves compatibility with the upstream OpenHands and OpenClaw sandbox workflows, but it also makes the cluster trust boundary intentionally privileged.
