# gitea wrapper chart

This wrapper chart keeps local/offline-friendly platform dependency wiring while pinning the upstream `gitea/gitea` chart version.

The default application image is the upstream rootless variant, configured as `docker.gitea.com/gitea:1.25.5` with `image.rootless=true` so the chart resolves to `docker.gitea.com/gitea:1.25.5-rootless`. The dedicated `docker.gitea.com` registry uses a single `gitea` path segment, so the older Docker Hub-style `gitea/gitea` repository path must not be used there.

## Deployment model

This chart is now a **true wrapper** around the upstream Gitea chart:

- Local workload templates were removed.
- Workload resources are rendered only by the upstream dependency.
- Wrapper values pass through under `gitea.*` (for example `gitea.gitea.config.*`, `gitea.gitea.ingress.*`, `gitea.gitea.persistence.*`).

No adaptor templates are required at this time.

## External database/cache posture

This wrapper is configured for centralized backends:

- `gitea.gitea.postgresql.enabled=false`
- `gitea.gitea.postgresql-ha.enabled=false`
- `gitea.gitea.redis.enabled=false`
- `gitea.gitea.redis-cluster.enabled=false`

Set non-sensitive DB host/name/user in `gitea.gitea.config.database.*` and inject sensitive settings through upstream chart secret/env mechanisms (for example `gitea.gitea.additionalConfigFromEnvs` and `gitea.gitea.additionalConfigSources`).
