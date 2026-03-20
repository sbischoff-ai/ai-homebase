# Networking and exposure model

This platform is designed so enabled services are reachable through ingress by default.

## Recommended default exposure

- Every enabled service in the stack renders an ingress by default.
- Base values provide reusable internal hostnames, and overlays replace them with target-specific hostnames and ingress classes.
- Nextcloud should still use a dedicated hostname because it is a user-facing content service.
- Apply TLS and any external access controls in your environment overlays when exposure moves beyond a trusted internal network.

## Runtime trust boundary

OpenHands uses in-cluster Kubernetes runtime sandboxes. OpenClaw uses the `docker` backend and reaches the standard remote Docker daemon over SSH; when browser sandboxes run remotely, set `openclaw.agents.defaults.sandbox.browser.cdpSourceRange` to the CIDR that the remote host sees for traffic coming from the cluster.

## Local k3d ingress host access

The shipped `values-k3d.yaml` profile points the `OpenClaw`, `OpenHands`, and `Infisical` Ingresses at the Helm-managed `ingress-nginx` controller by using the `nginx` ingress class. `*.localtest.me` usually resolves to `127.0.0.1` automatically, but some NixOS setups do not provide that resolution out of the box. If browser access to local ingress hosts such as `openclaw.localtest.me`, `openhands.localtest.me`, or `infisical.localtest.me` fails, add explicit host mappings as described in [`docs/deployment-k3d.md`](./deployment-k3d.md#4-local-ingress-host-access-dnshosts). That same section now also includes a complete NixOS host example covering `virtualisation.docker.enable`, an Incus `preseed` for `incusbr0`, the required `networking.nftables.enable = true`, and `networking.extraHosts` entries for the shipped local hostnames.
