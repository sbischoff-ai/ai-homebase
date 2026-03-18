# ai-homebase

## What is this repo?
`ai-homebase` is a Helm-based AI homelab stack centered on OpenClaw and OpenHands, with optional services such as Nextcloud, Paperless-ngx, Gitea, Infisical, and wg-easy.

The repository now supports exactly two deployment targets:

- **k3d** for local testing.
- **k3s** for the productive homelab server.

OpenHands and OpenClaw are both configured around **Docker-backed sandboxing** in these supported environments by mounting the host Docker socket into the pod. This is an intentional trusted-boundary homelab design, not a portable multi-tenant pattern.

## Quick start

Start with the deployment landing page:

- [How do I deploy and use it? (`docs/deployment.md`)](./docs/deployment.md)

Essential local commands:

```bash
export OPENAI_API_KEY="<your-openai-api-key>"
./scripts/k3d-local-bootstrap.sh --cluster-name ai-homebase-dev
helm dependency update charts/platform-stack
make lint
make render > /tmp/platform-stack.yaml
make render-k3d > /tmp/platform-stack-k3d.yaml
./scripts/install.sh --profile k3d
```

Essential k3s commands:

```bash
helm dependency update charts/platform-stack
./scripts/lint.sh --values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3s.yaml
./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3s.yaml > /tmp/platform-stack-k3s.yaml
./scripts/install.sh --profile k3s
```

`k3d-local-bootstrap.sh` creates a dedicated kubeconfig for the local cluster so your setup is isolated from other projects and does not depend on your existing `KUBECONFIG` merge state.
The local k3d bootstrap also disables the default k3s Traefik add-on during cluster creation so Helm-managed `ingress-nginx` is the single intended HTTP/HTTPS ingress controller. It mounts the host Docker socket into every k3d node container at `/var/run/docker.sock` so the existing OpenHands and OpenClaw pod `hostPath` mounts resolve to a real Unix socket during local sandbox execution.
By default, helper scripts print concise progress updates and write full command logs to `/tmp/ai-homebase-bootstrap-<timestamp>.log`.
Use `--verbose` (or `BOOTSTRAP_VERBOSE=1`) when you want full live command output in the terminal.

For complete command coverage, see [`docs/commands.md`](./docs/commands.md).

> Local k3d note: `*.localtest.me` usually resolves to `127.0.0.1` automatically, but some NixOS setups do not provide that resolution out of the box. If browser access to local ingress hosts such as `openhands.localtest.me`, `wg.localtest.me`, or `infisical.localtest.me` fails, add explicit host mappings as described in [`docs/deployment-k3d.md`](./docs/deployment-k3d.md#5-local-ingress-host-access-dnshosts).

## Documentation map

- [Full docs taxonomy (`docs/README.md`)](./docs/README.md)

## Where to go next

- Configuration layering and target overlays: [`docs/configuration.md`](./docs/configuration.md)
- Service contracts, toggles, and secret wiring: [`docs/services.md`](./docs/services.md)
- Ingress and exposure patterns: [`docs/networking.md`](./docs/networking.md)
- Persistence and storage planning: [`docs/storage.md`](./docs/storage.md)
- Architecture and component boundaries: [`docs/architecture.md`](./docs/architecture.md)
