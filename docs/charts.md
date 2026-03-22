# Helm chart notes

## Shared global values

Use `global.*` for shared defaults such as hostnames, storage class, image pull secrets, labels, and pod annotations.

## platform-stack composition

`platform-stack` is an umbrella chart with dependency toggles for:

- `openclaw.enabled`
- `nextcloud.enabled`
- `gitea.enabled`
- `vaultwarden.enabled`
- `paperlessNgx.enabled`

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

The `openclaw` chart renders an `openclaw.json` ConfigMap entry from structured `openclaw.*` values, then uses it only to bootstrap `/home/node/.openclaw/openclaw.json` when that persistent file does not exist yet. Once bootstrapped, OpenClaw keeps using the PVC-backed file so UI-driven settings survive pod restarts and redeploys.

Relevant sandbox-related value paths:

- `openclaw.agents.defaults.sandbox.mode`
- `openclaw.agents.defaults.sandbox.scope`
- `openclaw.agents.defaults.sandbox.docker.*`
- `openclaw.agents.defaults.sandbox.browser.*`
- `openclaw.remoteDocker.*`
- `openclaw.plugins.*`

The supported OpenClaw posture keeps `openclaw.remoteDocker.enabled=true` and points `openclaw.remoteDocker.dockerHost` at the target's Incus-backed remote Docker endpoint, with overlays only adjusting hostnames, Secret names, or image details.
