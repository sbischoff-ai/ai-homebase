# gitea wrapper chart

This wrapper chart keeps local/offline-friendly platform dependency wiring while pinning the upstream `gitea/gitea` chart version.

The default application image is the upstream rootless variant, configured with `image.repository=gitea` and `image.rootless=true`, so the upstream chart resolves the workload image to `docker.gitea.com/gitea:1.25.5-rootless`. The upstream chart already supplies the `docker.gitea.com` registry separately, so repeating it inside `image.repository` creates the invalid `docker.gitea.com/docker.gitea.com/gitea` pull path.

## Deployment model

This chart is now a **true wrapper** around the upstream Gitea chart:

- Local workload templates were removed.
- Workload resources are rendered only by the upstream dependency.
- Wrapper values pass through under `gitea.*`. Because the upstream chart itself keeps application settings under its own `gitea.*` block, wrapper callers must use paths like `gitea.gitea.gitea.config.*`, while top-level upstream settings such as image/ingress/persistence remain at `gitea.gitea.image.*`, `gitea.gitea.ingress.*`, and `gitea.gitea.persistence.*`.

No adaptor templates are required at this time.

## External database/cache posture

This wrapper is configured for centralized backends. The upstream Gitea chart now uses `valkey` / `valkey-cluster` for its bundled cache dependency, so the wrapper disables those subcharts explicitly and points Gitea at the umbrella chart's shared Redis service via secret-backed `app.ini` settings:

- `gitea.gitea.postgresql.enabled=false`
- `gitea.gitea.postgresql-ha.enabled=false`
- `gitea.gitea.valkey.enabled=false`
- `gitea.gitea.valkey-cluster.enabled=false`

Set non-sensitive DB host/name/user in `gitea.gitea.gitea.config.database.*` and inject sensitive settings through upstream chart environment-backed config sources. The shipped defaults now populate `gitea.gitea.gitea.additionalConfigFromEnvs` from the `gitea-config-secrets` Secret so the upstream `init-app-ini` container writes `database`, `session`, `cache`, `queue`, and `global_lock` settings into `app.ini` before database initialization runs.

For bootstrap-driven workflows, `scripts/bootstrap-secrets.sh` creates that `gitea-config-secrets` Secret with the env-style keys `GITEA__database__PASSWD`, `GITEA__session__PROVIDER_CONFIG`, `GITEA__cache__HOST`, `GITEA__queue__CONN_STR`, `GITEA__global_lock__SERVICE_CONN_STR`, and `GITEA_RUNNER_REGISTRATION_TOKEN`, plus `gitea-admin-secret` for the upstream chart's admin bootstrap. The umbrella chart's shared PostgreSQL bootstrap Job then reconciles the live `gitea` role/database, while the Gitea `preExtraInitContainers` SQL gate waits for direct login success before the upstream init containers proceed. When the bootstrap config leaves those credentials empty, the first-run flow generates fresh values.

## Actions posture

The wrapper now reserves its own top-level `actions.*` values for bootstrap-owned Gitea Actions companion settings. From the umbrella chart, those render at `gitea.actions.*`, while upstream Gitea application settings still pass through under `gitea.gitea.*`. The shipped defaults leave that wrapper-owned Actions posture enabled so normal bootstrap paths provision the companion runner VM and registration flow automatically.

Enabling that block does not embed runners into the chart; it declares the dedicated runner VM/bootstrap contract while the actual `act_runner` container is created by host-side bootstrap after Gitea, the internal CA, and the registry are ready.
