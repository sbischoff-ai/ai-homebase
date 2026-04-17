# Security

This page covers secrets, trust boundaries, bootstrap-sensitive inputs, and the internal CA posture.

## Secret Model

The repository keeps real operator secrets out of versioned Helm values.

The intended split is:

- `bootstrap.example.toml`: committed template
- `bootstrap.local.toml`: local operator input, ignored by git
- chart values: only references and non-secret defaults
- Kubernetes Secrets: the live secret material used at runtime

Bootstrap-managed Secrets include:

- `openclaw-secrets`
- `coder-credentials`
- `reviewer-credentials`
- `openclaw-remote-docker-ssh`
- `gitea-config-secrets`
- `gitea-admin-secret`
- `vaultwarden-config-secrets`
- `nextcloud-config-secrets`
- `paperless-config-secrets`
- shared PostgreSQL and Redis auth Secrets

The canonical bootstrap workflow is `scripts/bootstrap-secrets.sh`, which creates the runtime Secrets for a fresh cluster from `bootstrap.local.toml`. Operators can later move long-lived secret management into encrypted manifests under [`secrets/`](../secrets/) with the guidance in [`docs/secrets.md`](./secrets.md).

## User-Provided Tokens

Some values are intentionally operator-supplied rather than always generated:

- `openclaw_gateway_token`
- `vaultwarden_admin_token`

`vaultwarden_admin_token` maps to Vaultwarden `ADMIN_TOKEN`. It enables the Vaultwarden admin panel so operators can create users manually after bootstrap. This repo does not bootstrap Vaultwarden users directly.

## Generated Secrets

When a generated secret field in `bootstrap.local.toml` is empty, the bootstrap flow creates a fresh value for that first install.

Set a value explicitly in `bootstrap.local.toml` when you need a specific credential instead of a generated one.

## Internal CA and TLS

The platform defaults install `cert-manager`, bootstrap an internal root CA, and issue the OpenClaw ingress certificate from that CA.

Important rules:

- distribute only `ca.crt`
- never export or distribute the CA private key
- trust the internal CA only on devices that should access the stack

Example CA export:

```bash
kubectl get secret platform-stack-root-ca -n <namespace> -o jsonpath='{.data.ca\.crt}' | base64 -d > platform-stack-root-ca.crt
```

## OpenClaw Remote Docker Trust Boundary

OpenClaw is the control plane entrypoint, but sandbox execution happens on the supported remote Docker daemon reached over SSH.

The SSH Secret must provide:

- `id_ed25519`
- `known_hosts`

The init container locks down permissions before the main OpenClaw container starts. If those files are missing or empty, startup is expected to fail.

## Related Pages

- Architecture: [architecture.md](./architecture.md)
- Networking: [networking.md](./networking.md)
- Service contracts: [services.md](./services.md)
