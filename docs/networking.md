# Networking and exposure model

This platform is designed with explicit public/private boundaries between core and optional services.

## Recommended default exposure

- **Exposed by default (when enabled):** services with user-facing UIs/APIs (OpenClaw, OpenHands, Nextcloud, Gitea, Paperless-ngx, Infisical, wg-easy web UI).
- **Optional private posture per environment:** use internal ingress classes, VPN-only access, or private load balancers when required.

## Ingress controls

Each service has independent ingress values under `<service>.ingress.*`.

Common requirements per exposed service:

- Explicit `ingressClassName` (or equivalent class field).
- TLS configured with valid certificate issuer.
- Stable hostnames mapped in DNS.

OpenHands ingress is enabled by default in the platform profiles so the UI/API is reachable.

## AKS ingress posture

Typical AKS pattern:

- NGINX ingress controller.
- cert-manager for TLS automation.
- external-dns (optional) for DNS lifecycle automation.

If a service must remain private, use internal ingress classes, VPN-only access, or private load balancers in environment overlays.

## wg-easy networking guidance

- Expose UDP VPN endpoint with narrow source/routing controls.
- If the web UI is exposed, protect it with strong authn/authz and IP/rate controls.

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
