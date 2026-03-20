# Deployment entrypoint

Use this page as the deployment entrypoint for `ai-homebase`.

## I want local k3d

Choose this path when you want a local workstation cluster for smoke tests, iteration, or trying the stack before touching the homelab server.

- Read [`docs/deployment-k3d.md`](./deployment-k3d.md) for the full local bootstrap, manual install flow, ingress access notes, and troubleshooting.
- Use the recommended bootstrap when you want the fastest supported path:

```bash
export OPENAI_API_KEY="<your-openai-api-key>"
./scripts/k3d-local-bootstrap.sh --cluster-name ai-homebase-dev
```

## I want homelab k3s

Choose this path when you are deploying to the supported long-running homelab server and need the validation, install, and post-install operating workflow.

- Read [`docs/runbook-homelab.md`](./runbook-homelab.md) for pre-apply checks, install or upgrade commands, and health checks.
- Use the supported install entry command after your overlays and secrets are ready:

```bash
./scripts/install.sh --profile k3s
```

For dependency refresh, lint, render, and alternate install wrappers, read [`docs/commands.md`](./commands.md).

## I need install commands

Choose this section when you already know your target and only need the canonical command catalog. Read [`docs/commands.md`](./commands.md).

## I need prerequisites

Choose this section when you need a quick checklist before starting either deployment path.

- Kubernetes and Helm tooling are installed and working.
- The local `k3d` path has `k3d` and Docker available.
- The standard OpenClaw sandbox path has Incus installed on the host and initialized for the remote Docker VM; on NixOS, use the complete host example in [`docs/deployment-k3d.md`](./deployment-k3d.md#4-local-ingress-host-access-dnshosts).
- The `k3s` path has a reachable cluster and a working default storage class.
- The `k3s` path also has a reachable SSH-backed remote Docker or Incus VM for OpenClaw, plus the matching Kubernetes Secret.
- You have planned your values overlays and secret references.
