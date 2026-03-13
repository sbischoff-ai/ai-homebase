# Networking and exposure model

This platform is designed with explicit public/private boundaries between core and optional services.

## Recommended default exposure

- **Public by default:** OpenClaw ingress.
- **Private by default:** OpenHands, Infisical, wg-easy web UI.
- **Optional public exposure:** Nextcloud, Gitea, Paperless-ngx (only when needed).

## Ingress controls

Each service has independent ingress values under `<service>.ingress.*`.

Common requirements per exposed service:

- Explicit `ingressClassName` (or equivalent class field).
- TLS configured with valid certificate issuer.
- Stable hostnames mapped in DNS.

Keep OpenHands ingress disabled unless there is a reviewed requirement.

## AKS ingress posture

Typical AKS pattern:

- NGINX ingress controller.
- cert-manager for TLS automation.
- external-dns (optional) for DNS lifecycle automation.

For internal-only services, prefer internal ingress or cluster-private access instead of direct public load balancers.

## wg-easy networking guidance

- Keep admin web UI private.
- Expose UDP VPN endpoint with narrow source/routing controls.
- Avoid public admin UI exposure without compensating controls.

## NetworkPolicy guidance

NetworkPolicy fields are present as operator hooks, but rules are environment-specific.

Recommended progression:

1. Enable policy for internal/admin services first.
2. Add explicit allow rules for required namespaces/ports.
3. Deny all unspecified traffic.
4. Validate service-to-service paths with smoke tests.

## Intentional placeholders and hardening gaps

This repo does not ship production-ready policy matrices, WAF policy, or DDoS controls out of the box.

Before production, define:

- Namespace/service traffic contracts.
- Ingress security controls (rate limits, auth integration, mTLS where needed).
- Operational runbooks for certificate rotation and DNS incidents.
