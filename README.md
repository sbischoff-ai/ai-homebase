# ai-homebase

## What is this repo?
`ai-homebase` is a Helm-based AI homelab stack centered on OpenClaw and OpenHands, with optional services such as Nextcloud, Paperless-ngx, Gitea, Infisical, and wg-easy.

The repository now supports exactly two deployment targets:

- **k3d** for local testing.
- **k3s** for the productive homelab server.

OpenClaw now ships with a Docker sandbox configuration that is standardized on a remote Docker daemon reached through Docker's SSH transport. The chart exposes structured values for the sandbox images, browser/CDP network policy, and the required remote-Docker SSH wiring inside the OpenClaw pod. OpenHands runs as a lightweight in-cluster control plane that launches per-session **Kubernetes runtime** sandboxes inside the cluster.

## Quick start

Start with the deployment landing page:

- [How do I deploy and use it? (`docs/deployment.md`)](./docs/deployment.md)

Essential local commands:

```bash
export OPENAI_API_KEY="<your-openai-api-key>"
./scripts/k3d-local-bootstrap.sh --cluster-name ai-homebase-dev
./scripts/k3d-local-teardown.sh --cluster-name ai-homebase-dev
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

`k3d-local-bootstrap.sh` creates a dedicated kubeconfig for the local cluster, exports `KUBECONFIG` to that file for the script run, and keeps local setup isolated from your existing kubeconfig merge state.
The local k3d bootstrap also disables the default k3s Traefik add-on during cluster creation so Helm-managed `ingress-nginx` is the single intended HTTP/HTTPS ingress controller. It still uses Docker to run the local k3d node containers themselves, while OpenClaw is configured by default to target the Incus-backed remote Docker daemon over SSH and therefore expects an OpenClaw image that includes Docker CLI + OpenSSH client support.
The same local bootstrap now also creates a separate lightweight Incus VM (`openclaw-sandbox` by default) from `images:debian/12/cloud`, sized for **2 vCPU**, **6 GiB RAM**, and a small dedicated root disk. The guest installs only Docker Engine, SSH, and minimal supporting packages so it can act as a narrow remote Docker sandbox appliance for OpenClaw Docker/browser sandboxes.
By default, helper scripts print concise progress updates and write full command logs to `/tmp/ai-homebase-bootstrap-<timestamp>.log`.
Use `--verbose` (or `BOOTSTRAP_VERBOSE=1`) when you want full live command output in the terminal.

For complete command coverage, see [`docs/commands.md`](./docs/commands.md).

> Local k3d note: the shipped `values-k3d.yaml` profile points the `wg-easy`, `OpenHands`, and `Infisical` Ingresses at the Helm-managed `ingress-nginx` controller by using the `nginx` ingress class. `*.localtest.me` usually resolves to `127.0.0.1` automatically, but some NixOS setups do not provide that resolution out of the box. If browser access to local ingress hosts such as `openhands.localtest.me`, `wg.localtest.me`, or `infisical.localtest.me` fails, add explicit host mappings as described in [`docs/deployment-k3d.md`](./docs/deployment-k3d.md#4-local-ingress-host-access-dnshosts). That same section now also includes a complete NixOS host example covering `virtualisation.docker.enable`, an Incus `preseed` for `incusbr0`, `networking.nftables.enable`, and `networking.extraHosts` entries for the shipped local hostnames.

## Documentation map

- [Full docs taxonomy (`docs/README.md`)](./docs/README.md)

## Where to go next

- Configuration layering and target overlays: [`docs/configuration.md`](./docs/configuration.md)
- Service contracts, toggles, and secret wiring: [`docs/services.md`](./docs/services.md)
- Ingress and exposure patterns: [`docs/networking.md`](./docs/networking.md)
- Persistence and storage planning: [`docs/storage.md`](./docs/storage.md)
- Architecture and component boundaries: [`docs/architecture.md`](./docs/architecture.md)
