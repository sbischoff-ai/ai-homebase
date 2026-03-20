# AGENTS.md

## Start here (before editing)
- Read project intent and workflow boundaries: `README.md`.
- Read values layering and target model: `docs/configuration.md`.
- Read service toggles, defaults, and secret contracts: `docs/services.md`.

## Canonical validation commands
- Update umbrella dependencies when chart metadata changes:
  - `helm dependency update charts/platform-stack`
- Lint shared defaults:
  - `./scripts/lint.sh --values-file charts/platform-stack/values.yaml`
- Lint layered k3d profile:
  - `./scripts/lint.sh --values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3d.yaml`
- Lint layered k3s profile:
  - `./scripts/lint.sh --values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3s.yaml`
- Render shared defaults:
  - `./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml > /tmp/platform-stack.yaml`
- Render layered k3d profile:
  - `./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3d.yaml > /tmp/platform-stack-k3d.yaml`
- Render layered k3s profile:
  - `./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3s.yaml > /tmp/platform-stack-k3s.yaml`
- Render with explicit toggle checks:
  - `./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml --disable-service nextcloud --disable-service gitea > /tmp/platform-stack-core-only.yaml`

## Change-target rules (charts vs overlays vs docs)
- Change `charts/<service>/` when you need template, chart metadata, image, probes, resources, secret wiring, or service defaults updated for that service.
- Change `charts/platform-stack/` when you need composition, dependency wiring, umbrella defaults, or cross-service orchestration updates.
- Change overlay values files (`charts/platform-stack/values-k3d.yaml` and `charts/platform-stack/values-k3s.yaml`) when behavior must differ by supported target without changing base chart logic.
- Change docs in `docs/` and command references in `README.md` whenever operators must do something new, a default/toggle meaning changes, or validation steps change.
- Do not encode persistent environment decisions only as CLI `--set`; store them in overlay values files.

## Required updates when toggles/values change
When adding/removing/renaming/changing a value key or toggle semantics, update all applicable files in the same change:
- Source values definitions/defaults in chart values files.
- `docs/configuration.md` for layering, value hierarchy, and operator usage guidance.
- `docs/services.md` for toggle names, service posture, and secret/runtime contract updates.
- `README.md` command examples/profile guidance when operator workflows changed.
- Any affected example overlays in `examples/`.

If toggle behavior changed, include at least one rendered manifest check using `./scripts/template.sh` that demonstrates expected enable/disable output.

## Troubleshooting (Helm/chart issues)
- Dependency errors (`found in Chart.yaml, but missing in charts/`):
  - Run `helm dependency update charts/platform-stack`.
- YAML/template parse failures:
  - Re-run with exact layered inputs using `./scripts/template.sh ...` and inspect the generated `/tmp/*.yaml` around the reported object.
- Value key seems ignored:
  - Confirm key path/casing matches chart schema (for example `paperlessNgx` vs `paperless-ngx`).
- Service did not disable:
  - Verify effective layered values order and final toggle value with the same `--values-file` ordering used in deployment.
- Secret/env wiring failures:
  - Check `existingSecret`, `secretKeys.*`, `envFromSecrets[]`, `secretRefs[]`, and `secretEnv[]` paths align with docs and rendered manifests.
- Ingress exposure mismatch:
  - Confirm both `<service>.enabled` and `<service>.ingress.enabled` (plus host values) in the active overlay set.
