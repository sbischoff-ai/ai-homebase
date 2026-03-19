# Networking and exposure model

This platform is designed with explicit private/public decisions per service.

## Recommended default exposure

- OpenClaw is private by default.
- OpenHands is private by default in base values, with ingress enabled by the shipped k3d and k3s overlays only where explicitly configured.
- Gitea and Paperless should generally remain internal-only unless you deliberately expose them.
- Nextcloud should use a dedicated hostname if published through ingress.

## Runtime trust boundary

OpenHands uses in-cluster Kubernetes runtime sandboxes. OpenClaw uses the `docker` backend and can optionally reach a remote Docker daemon over SSH; when browser sandboxes run remotely, set `openclaw.agents.defaults.sandbox.browser.cdpSourceRange` to the CIDR that the remote host sees for traffic coming from the cluster.

## wg-easy networking guidance

wg-easy has two distinct surfaces:

- the web UI/API,
- the WireGuard UDP endpoint.

Expose them intentionally and keep node prerequisites for WireGuard and iptables/NAT in place.
