# Networking and exposure model

This platform is designed with explicit public/private boundaries between core and optional services.

## Recommended default exposure

- **OpenClaw is private by default:** `Service` type `ClusterIP` with `openclaw.ingress.enabled: false` unless you explicitly configure internal/private ingress.
- **OpenClaw access path:** through VPN/private networking, for example `http://openclaw.default.svc.cluster.local:18789`.
- **Baseline chart defaults are private for core ingress:** both `openclaw.ingress.enabled: false` and `openhands.ingress.enabled: false` in `values.yaml`.
- **Optional private posture per environment:** use internal ingress classes, VPN-only access, or private load balancers when required.
- **Gitea is configured internal-only in shipped profiles:** `gitea.gitea.service.http.type: ClusterIP` with ingress host `gitea.vpn.homebase.internal` on internal ingress class `internal-nginx`; expected user flow is VPN connected -> internal host.

## Ingress controls

Each service has independent ingress values under `<service>.ingress.*`.
For precedence details when profile defaults differ, see values layering in [`docs/configuration.md`](./configuration.md#values-hierarchy-lowest-to-highest-precedence).

Common requirements per exposed service:

- Explicit `ingressClassName` (or equivalent class field).
- TLS configured with valid certificate issuer.
- Stable hostnames mapped in DNS.

OpenHands ingress is profile-specific: `values-dev.yaml` and `values-k3d.yaml` may enable ingress for local workflows, while AKS/prod profiles keep `openhands.ingress.enabled: false` unless explicitly enabled in environment overlays.

## AKS ingress posture

Typical AKS pattern:

- NGINX ingress controller.
- cert-manager for TLS automation.
- external-dns (optional) for DNS lifecycle automation.

If a service must remain private, use internal ingress classes, VPN-only access, or private load balancers in environment overlays.

## wg-easy networking guidance

- Expose UDP VPN endpoint with narrow source/routing controls.
- If the web UI is exposed, protect it with strong authn/authz and IP/rate controls.
- Ensure the configured wg-easy runtime Secret contains `WG_HOST` (reachable endpoint/FQDN) and `PASSWORD` (UI auth) before rollout.

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
