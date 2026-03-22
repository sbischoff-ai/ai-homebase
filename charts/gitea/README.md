# gitea wrapper chart

This wrapper chart keeps local/offline-friendly platform dependency wiring while pinning the upstream `gitea/gitea` chart version.

The default application image is the upstream rootless variant, configured with `image.repository=gitea` and `image.rootless=true`, so the upstream chart resolves the workload image to `docker.gitea.com/gitea:1.25.5-rootless`. The upstream chart already supplies the `docker.gitea.com` registry separately, so repeating it inside `image.repository` creates the invalid `docker.gitea.com/docker.gitea.com/gitea` pull path.

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
