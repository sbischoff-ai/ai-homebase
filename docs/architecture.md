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
In supported k3d and k3s deployments it acts as an in-cluster control plane and launches per-session Kubernetes runtime sandboxes inside the cluster.

## Supported targets

The repository intentionally supports only:

- `k3d` for local testing,
- `k3s` for the productive homelab deployment.

## Trust boundary

OpenClaw's Docker-socket-based sandboxing remains part of the homelab design for these targets, while OpenHands now uses namespace-scoped in-cluster Kubernetes runtime sandboxes. That keeps the OpenHands web/API pod lightweight and removes its dependency on host Docker socket access.
