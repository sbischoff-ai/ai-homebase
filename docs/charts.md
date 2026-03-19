# Helm chart notes

## Shared global values

Use `global.*` for shared defaults such as hostnames, storage class, image pull secrets, labels, and pod annotations.

## platform-stack composition

`platform-stack` is an umbrella chart with dependency toggles for:

- `openclaw.enabled`
- `openhands.enabled`
- `nextcloud.enabled`
- `gitea.enabled`
- `paperlessNgx.enabled`
- `infisical.enabled`
- `wgEasy.enabled`

It also includes shared backend dependencies:

- `sharedPostgresql.enabled`
- `sharedRedis.enabled`

## Snapshot (golden manifest) policy

Profiles covered by golden snapshots:

- `values` (`charts/platform-stack/values.yaml`)
- `values-k3d` (`values.yaml` layered with `values-k3d.yaml`)
- `values-k3s` (`values.yaml` layered with `values-k3s.yaml`)

Generate snapshots with:

```bash
helm dependency build charts/platform-stack
scripts/ci/update_golden.sh
scripts/ci/check_golden.sh
```

## OpenClaw dedicated config file

The `openclaw` chart renders an `openclaw.json` ConfigMap entry from structured `openclaw.*` values and mounts it into the pod.

Relevant sandbox-related value paths:

- `openclaw.agents.defaults.sandbox.mode`
- `openclaw.agents.defaults.sandbox.docker.image`
- `openclaw.agents.defaults.sandbox.docker.network`
- `openclaw.agents.defaults.sandbox.prune.*`
- `hostDockerSocket.*`

## OpenHands Kubernetes runtime wiring

The `openhands` chart now renders a managed `config.toml` with `[core] runtime = "kubernetes"` plus the upstream `[kubernetes]` block sourced from `openhands.runtime.mode` and `openhands.kubernetes.*`. It also creates namespace-scoped RBAC so the OpenHands pod can create and clean up runtime pods, services, ingresses, and PVCs without requiring cluster-admin.
