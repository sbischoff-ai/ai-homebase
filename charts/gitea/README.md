# gitea wrapper chart

This wrapper chart keeps local/offline-friendly platform dependency wiring while pinning the upstream `gitea/gitea` chart version.

## Probe defaults

Wrapper probe defaults are configured under `probes.liveness` and `probes.readiness`:

- `path: /api/healthz`
- `port: http`

These values are wired into the wrapper StatefulSet probes and should return **HTTP 200** for healthy pods.

If you change probe keys or paths, verify rendered manifests include the expected `livenessProbe`/`readinessProbe` and run a runtime check against the service endpoint.

## External database/cache posture

This wrapper is configured for centralized backends:

- `postgresql.enabled=false`
- `postgresql-ha.enabled=false`
- `redis.enabled=false`
- `redis-cluster.enabled=false`

Set non-sensitive DB host/name/user in `gitea.config.database.*` and inject sensitive settings (DB password + Redis URIs for session/cache/queue/global_lock) through Kubernetes Secrets using `gitea.additionalConfigFromEnvs` and `secretRefs[]`.
