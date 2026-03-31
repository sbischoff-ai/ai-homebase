# Architecture

`ai-homebase` is organized around one platform shape with two supported targets.

## Platform Shape

The stack has three main layers:

1. **Control plane**: OpenClaw
2. **Shared platform services**: PostgreSQL, Redis, cert-manager, ingress, internal PKI
3. **Optional user-facing apps**: Nextcloud, Gitea, Vaultwarden, Paperless-ngx

## Supported Targets

The repository intentionally supports only:

- `k3d` for local validation
- `k3s` for the real homelab deployment

The important constraint is that both targets converge on the same bootstrap and install model after cluster setup. `k3d` exists to exercise the same values, secrets, and service contracts before the `k3s` install.

## Bootstrap Model

The bootstrap flow is split into three phases:

1. **Target-specific cluster preparation**
   `k3d-local-bootstrap.sh` creates the local cluster and Incus-backed sandbox VM
   `install-k3s-ubuntu-2404.sh` prepares a fresh Ubuntu host for `k3s`
2. **Shared stack bootstrap**
   `bootstrap-stack.sh` creates bootstrap-managed Secrets and then runs the Helm apply path for either target
3. **GitOps handoff**
   The normal bootstrap path now runs `bootstrap-gitops.sh` before returning, enabling Argo CD against the in-cluster Gitea repo, triggering the first sync, and validating the Argo applications

`bootstrap.local.toml` is the operator input for both targets. It drives hostnames, provider keys, admin defaults, and user-supplied tokens.

## OpenClaw as the Center

OpenClaw is the main entrypoint and the main reason the stack exists. It renders its sandbox configuration from chart values, stores its persistent runtime state on its PVC, and reaches the supported remote Docker daemon over SSH.

The supporting services are not random add-ons. They exist to make the homelab useful around the AI plane:

- Nextcloud for user content
- Gitea for source control
- Vaultwarden for password management
- Paperless-ngx for documents

## See Also

- Security boundaries: [security.md](./security.md)
- Networking model: [networking.md](./networking.md)
- Service contracts: [services.md](./services.md)
