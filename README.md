# ai-homebase

## What is this repo?
`ai-homebase` is an AI-driven home lab stack for private self-hosting, general use, and agentic coding. OpenClaw is the core assistant experience: it is the main interface you use and the component that ties the rest of the stack into one cohesive environment.

Helm charts are used to package and deploy the stack across local and cluster targets, including optional services such as Nextcloud, Paperless-ngx, and Gitea. Defaults and service toggles are kept concise in umbrella values; see [`docs/configuration.md`](./docs/configuration.md) and [`docs/services.md`](./docs/services.md) for full layering and service contract details.

Use this repo when you want one self-hosted platform that combines an AI-first workspace with optional homelab services and a clear path from local iteration to full deployment.

## Quick start: deploy and use

Start with the canonical deployment landing page:

- [How do I deploy and use it? (`docs/deployment.md`)](./docs/deployment.md)

From there, choose the environment-specific flow for k3d local, AKS, or generic Kubernetes/homelab deployments.

Essential commands:

```bash
./scripts/k3d-local-bootstrap.sh --cluster-name ai-homebase-dev
helm dependency update charts/platform-stack
make lint
make render > /tmp/platform-stack-dev.yaml
./scripts/test-local-k3d.sh
./scripts/install.sh --profile dev --values-file charts/platform-stack/values-dev.yaml
```

`k3d-local-bootstrap.sh` creates a dedicated kubeconfig for the local cluster so your setup is isolated from other projects and does not depend on your existing `KUBECONFIG` merge state.
By default, helper scripts print concise progress updates and write full command logs to `/tmp/ai-homebase-bootstrap-<timestamp>.log`.
Use `--verbose` (or `BOOTSTRAP_VERBOSE=1`) when you want full live command output in the terminal.

`./scripts/install.sh --profile dev` assumes your kube context is already reachable and correctly selected.

For complete command coverage (Make targets, lint/render variants, CI-equivalent checks, and helper scripts), see [`docs/commands.md`](./docs/commands.md).

For day-2 operations on generic cluster/homelab installs, use the [Homelab operations runbook (`docs/runbook-homelab.md`)](./docs/runbook-homelab.md).

For a VPN-first homelab posture with public Nextcloud only, layer `charts/platform-stack/values-homelab-public-nextcloud.yaml` after `values-dev.yaml`. Keep Nextcloud on a dedicated host (`cloud.<domain>`) rather than a subpath for mobile/WebDAV/public-link compatibility.
Paperless defaults to service-only (`paperlessNgx.ingress.enabled: false`) across baseline and shipped overlays; only enable ingress in environment overlays when you intentionally need internal ingress routing.

## Documentation map

- [Full docs taxonomy (`docs/README.md`)](./docs/README.md)

## Where to go next
- Configuration layering and toggle model: [`docs/configuration.md`](./docs/configuration.md)
- Service contracts, toggles, and secret wiring: [`docs/services.md`](./docs/services.md)
- Ingress and exposure patterns: [`docs/networking.md`](./docs/networking.md)
- Persistence and storage planning: [`docs/storage.md`](./docs/storage.md)
- Architecture and component boundaries: [`docs/architecture.md`](./docs/architecture.md)
