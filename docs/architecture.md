# Architecture

`ai-homebase` is structured as a modular homelab platform:

1. **Core AI plane**: OpenClaw.
2. **Supporting personal-cloud services**: Nextcloud, Gitea, and Paperless-ngx.

## Core AI plane

### OpenClaw

OpenClaw is the main assistant experience.
It owns the rendered sandbox configuration used by the supported target overlays.

## Supported targets

The repository intentionally supports only:

- `k3d` for local testing,
- `k3s` for the productive homelab deployment.

## Trust boundary

OpenClaw ships with Docker/browser sandbox defaults plus standard remote-Docker SSH wiring in its chart values. The OpenClaw pod remains the control plane entrypoint, and Docker's own SSH transport carries sandbox execution to the supported Incus-backed remote daemon.
