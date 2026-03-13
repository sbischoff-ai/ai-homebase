# Networking exposure guide

This guide explains which services should be public by default vs private-by-default, and why.

## Recommended exposure model

- **Public by default**: `openclaw`
  - Serves as the primary external API/UI entrypoint.
- **Private by default**: `openhands`, `infisical`, `wg-easy` web UI
  - These are internal execution/admin surfaces and should remain restricted unless explicitly required.
- **Optional public exposure**: `nextcloud`, `gitea`, `paperless-ngx`
  - Enable ingress only when your use case needs direct user access and TLS/auth controls are in place.

## Global hostnames

`platform-stack` centralizes host defaults in `global.hosts`:

- `global.hosts.openclaw`
- `global.hosts.openhands`
- `global.hosts.nextcloud`
- `global.hosts.gitea`
- `global.hosts.paperless` (alias: `paperlessNgx`)
- `global.hosts.infisical`
- `global.hosts.wg` (aliases: `vpn`, `wgEasy`)

Each chart ingress template consumes these defaults when `ingress.hosts[].host` is left empty.

## wg-easy secure exposure guidance

Keep `wgEasy.ingress.enabled=false` by default.

Preferred patterns:

1. Expose only UDP WireGuard port (`service.vpnPort`) via `LoadBalancer` with source CIDR restrictions.
2. Keep web UI private (internal ingress class or no ingress) and access through VPN/bastion.
3. Require TLS + strong auth when exposing any admin web surface.

Avoid exposing the wg-easy web UI directly to the public internet without compensating controls.

## NetworkPolicy placeholders

Internal/admin services now include `networkPolicy` placeholders so you can define deny-by-default posture and explicit allow-lists:

- `openhands.networkPolicy.*`
- `infisical.networkPolicy.*`
- `wgEasy.networkPolicy.*`

Start by enabling `networkPolicy.enabled=true`, then add ingress/egress rules for trusted namespaces, controllers, and destinations only.
