# ai-homebase

## What is this repo?
`ai-homebase` is an AI-driven, developer-centric home lab stack for general use and agentic coding workflows. OpenClaw is the core assistant experience: it is the primary interface you use and the component that connects the rest of the stack into one cohesive environment.

Helm charts are the packaging and distribution mechanism that make this stack deployable across local and cluster targets, not the project’s primary identity. Defaults and service toggles are kept intentionally concise in the umbrella values, with deeper layering and service contract details documented in [`docs/configuration.md`](./docs/configuration.md) and [`docs/services.md`](./docs/services.md).

Use this repo when you want a single platform that gives developers an AI-first workspace plus optional homelab services, with a clear path from local iteration to production-style environments.

## Quick start: deploy and use

Start with the canonical deployment landing page:

- [How do I deploy and use it? (`docs/deployment.md`)](./docs/deployment.md)

From there, choose the environment-specific flow for k3d local, AKS, or generic Kubernetes/homelab deployments.

Essential commands:

```bash
./scripts/k3d-up.sh
helm dependency update charts/platform-stack
make lint
make render > /tmp/platform-stack-dev.yaml
./scripts/test-local-k3d.sh
./scripts/install.sh --profile dev --values-file charts/platform-stack/values-dev.yaml
```

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
