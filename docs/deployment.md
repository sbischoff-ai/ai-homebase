# Deployment guide chooser

Choose the workflow that matches your target, then follow the linked guide.

## Local `k3d`

Use this path for smoke tests and local iteration.

- Primary guide: [`deployment-k3d.md`](./deployment-k3d.md)
- Deep troubleshooting: [`k3d-troubleshooting.md`](./k3d-troubleshooting.md)

```bash
export OPENAI_API_KEY="<your-openai-api-key>"
# or ANTHROPIC_API_KEY / GEMINI_API_KEY / XAI_API_KEY / MOONSHOT_API_KEY
# optionally add BRAVE_API_KEY / PERPLEXITY_API_KEY for built-in web search
./scripts/k3d-local-bootstrap.sh --cluster-name ai-homebase-dev
```

## Homelab `k3s`

Use this path for the long-running supported homelab deployment.

- Primary guide: [`runbook-homelab.md`](./runbook-homelab.md)
- Command catalog: [`commands.md`](./commands.md)

```bash
./scripts/install.sh --profile k3s
```

## Before either path

- Confirm Helm and Kubernetes tooling are installed.
- Prepare the right values overlays and Secret references.
- For local `k3d`, make sure `k3d`, Docker, and the OpenClaw remote Docker prerequisites are ready.
- For homelab `k3s`, make sure the cluster, storage class, and remote Docker or Incus endpoint are reachable.
