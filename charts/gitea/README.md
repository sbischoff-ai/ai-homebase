# gitea wrapper chart

This wrapper chart keeps local/offline-friendly platform dependency wiring while pinning the upstream `gitea/gitea` chart version.

## Probe defaults

Wrapper probe defaults are configured under `probes.liveness` and `probes.readiness`:

- `path: /api/healthz`
- `port: http`

These values are wired into the wrapper StatefulSet probes and should return **HTTP 200** for healthy pods.

If you change probe keys or paths, verify rendered manifests include the expected `livenessProbe`/`readinessProbe` and run a runtime check against the service endpoint.
