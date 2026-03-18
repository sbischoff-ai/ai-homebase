# Networking and exposure model

This platform is designed with explicit private/public decisions per service.

## Recommended default exposure

- OpenClaw is private by default.
- OpenHands is private by default in base values, with ingress enabled by the shipped k3d and k3s overlays only where explicitly configured.
- Gitea and Paperless should generally remain internal-only unless you deliberately expose them.
- Nextcloud should use a dedicated hostname if published through ingress.

## Docker-sandbox trust boundary

OpenHands and OpenClaw both mount the host Docker socket in the supported target overlays.
That is a **security-sensitive trusted-boundary design** for self-hosted k3d/k3s deployments.
It should not be reused unchanged for multi-tenant or hostile environments.

## wg-easy networking guidance

wg-easy has two distinct surfaces:

- the web UI/API,
- the WireGuard UDP endpoint.

Expose them intentionally and keep node prerequisites for WireGuard and iptables/NAT in place.
