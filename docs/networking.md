# Networking and exposure model

This platform is designed so enabled services are reachable through ingress by default.

## Recommended default exposure

- Every enabled service in the stack renders an ingress by default.
- Base values provide reusable internal hostnames, and overlays replace them with target-specific hostnames and ingress classes.
- Nextcloud should still use a dedicated hostname because it is a user-facing content service.
- Apply TLS and any external access controls in your environment overlays when exposure moves beyond a trusted internal network.

## Runtime trust boundary

OpenHands uses in-cluster Kubernetes runtime sandboxes. OpenClaw uses the `docker` backend and reaches the standard remote Docker daemon over SSH; when browser sandboxes run remotely, set `openclaw.agents.defaults.sandbox.browser.cdpSourceRange` to the CIDR that the remote host sees for traffic coming from the cluster.
