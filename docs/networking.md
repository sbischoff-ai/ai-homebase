# Networking and exposure model

This platform is designed with explicit private/public decisions per service.

## Recommended default exposure

- OpenClaw is private by default.
- OpenHands is private by default in base values, with ingress enabled by the shipped k3d and k3s overlays only where explicitly configured.
- Gitea and Paperless should generally remain internal-only unless you deliberately expose them.
- Nextcloud should use a dedicated hostname if published through ingress.

## Runtime trust boundary

OpenHands uses in-cluster Kubernetes runtime sandboxes. OpenClaw currently only carries a configured `docker` sandbox backend value in the supported deployment path, without the runtime integration needed to execute Docker-backed sandboxes.

## wg-easy networking guidance

wg-easy has two distinct surfaces:

- the web UI/API,
- the WireGuard UDP endpoint.

Expose them intentionally and keep node prerequisites for WireGuard and iptables/NAT in place.
