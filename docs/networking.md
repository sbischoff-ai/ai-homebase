# Networking

This page covers hostname strategy, ingress exposure, TLS posture, and local host access.

## Hostname Model

Service hostnames can be overridden in `bootstrap.local.toml`. The bootstrap-generated values layer then applies those hostnames consistently across both `k3d` and `k3s`.

Relevant services:

- OpenClaw
- Nextcloud
- Gitea
- Vaultwarden
- Postfix relay
- Paperless-ngx

## Ingress Model

- Enabled services are ingress-exposed by default
- `k3d` and `k3s` both use the `nginx` ingress class in the supported overlays
- Nextcloud and Vaultwarden should keep dedicated hostnames rather than path-sharing

## TLS Posture

The standard platform posture includes `cert-manager`, an internal CA, an OpenClaw ingress certificate, and an internal-CA Vaultwarden ingress certificate.

Important points:

- the internal CA private key stays inside Kubernetes
- clients must trust the exported `ca.crt`
- the root CA is for trusted internal use, not public internet trust

For the full trust and secret model, see [security.md](./security.md).

## Mail DNS

The bundled Postfix relay is for outbound mail from cluster services such as Nextcloud and Vaultwarden. Configure the owned mail domain in `bootstrap.local.toml` under `[mail]`:

- `mail.domain`
- `mail.smtp_host`
- `mail.from_localpart`

Recommended DNS and provider work for the direct-delivery posture:

1. Create an `A` or `AAAA` record for `mail.smtp_host`, for example `smtp.example.com`.
2. Publish an `SPF` record for `mail.domain` that authorizes the public IP used by the `k3s` server.
3. Configure provider-side reverse DNS so the server IP resolves back to `mail.smtp_host`.
4. If you later add DKIM, publish the selector record before relying on it for deliverability.

For `k3d`, the relay is only for local functional validation. Real internet deliverability is expected only from the `k3s` host.

## Nextcloud Public DNS

Nextcloud supports two hostnames:

- private: `hosts.nextcloud`
- public: `hosts.nextcloud_public`

The private hostname is rendered on both supported targets. The public hostname is only exposed when the `k3s` overlay is active; `k3d` keeps the public ingress disabled even if `hosts.nextcloud_public` is present in `bootstrap.local.toml`.

To make the public hostname work on `k3s`:

1. set `hosts.nextcloud_public` in `bootstrap.local.toml`
2. create public DNS for that name at your domain provider so it resolves to the ingress entrypoint for the homelab
3. make sure the public ingress can be reached on ports `80` and `443` so cert-manager can complete the Let's Encrypt flow

The standard chart posture uses two separate ingress resources for Nextcloud:

- private ingress with the internal CA issuer annotation
- public ingress with the Let's Encrypt issuer annotation

Example issuer names used by the shipped values:

- internal: `platform-stack-root-ca`
- public: `letsencrypt-production`

Example `ClusterIssuer` snippets:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: platform-stack-root-ca
spec:
  ca:
    secretName: platform-stack-root-ca
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    email: you@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-production-account-key
    solvers:
      - http01:
          ingress:
            class: nginx
```

Vaultwarden stays on the internal CA path on both supported targets. Its ingress now uses a dedicated TLS Secret, `vaultwarden-tls`, issued by `platform-stack-root-ca`.

## OpenClaw Remote Docker Network Boundary

OpenClaw reaches the remote Docker daemon over SSH. When browser sandboxes run remotely, set `openclaw.agents.defaults.sandbox.browser.cdpSourceRange` so the remote host accepts CDP traffic from the cluster network it actually sees.

## Local `k3d` Host Access

If your chosen local hostnames do not resolve automatically:

1. check the values in `bootstrap.local.toml`
2. add host mappings for those names to `127.0.0.1`
3. retry the ingress endpoints

The shipped example names use `*.localtest.me`, which usually resolves to loopback automatically.

For deeper local networking and Incus notes, see [k3d-troubleshooting.md](./k3d-troubleshooting.md).
