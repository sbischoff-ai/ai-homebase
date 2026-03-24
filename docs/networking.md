# Networking

This page covers hostname strategy, ingress exposure, TLS posture, and local host access.

## Hostname Model

Service hostnames can be overridden in `bootstrap.local.toml`. The bootstrap-generated values layer then applies those hostnames consistently across both `k3d` and `k3s`.

Relevant services:

- OpenClaw
- Nextcloud
- Gitea
- Vaultwarden
- Paperless-ngx

## Ingress Model

- Enabled services are ingress-exposed by default
- `k3d` and `k3s` both use the `nginx` ingress class in the supported overlays
- Nextcloud and Vaultwarden should keep dedicated hostnames rather than path-sharing

## TLS Posture

The standard platform posture includes `cert-manager`, an internal CA, and an OpenClaw ingress certificate.

Important points:

- the internal CA private key stays inside Kubernetes
- clients must trust the exported `ca.crt`
- the root CA is for trusted internal use, not public internet trust

For the full trust and secret model, see [security.md](./security.md).

## OpenClaw Remote Docker Network Boundary

OpenClaw reaches the remote Docker daemon over SSH. When browser sandboxes run remotely, set `openclaw.agents.defaults.sandbox.browser.cdpSourceRange` so the remote host accepts CDP traffic from the cluster network it actually sees.

## Local `k3d` Host Access

If your chosen local hostnames do not resolve automatically:

1. check the values in `bootstrap.local.toml`
2. add host mappings for those names to `127.0.0.1`
3. retry the ingress endpoints

The shipped example names use `*.localtest.me`, which usually resolves to loopback automatically.

For deeper local networking and Incus notes, see [k3d-troubleshooting.md](./k3d-troubleshooting.md).
