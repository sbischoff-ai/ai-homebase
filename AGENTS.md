# AGENTS.md

## Start here (before editing)
- Read project intent and workflow boundaries: `README.md`.
- Read values layering and target model: `docs/configuration.md`.
- Read service toggles, defaults, and secret contracts: `docs/services.md`.

## Canonical validation commands
- Update nested wrapper + umbrella dependencies when chart metadata changes or a render must include wrapper-managed resources:
  - `helm dependency update charts/argo-cd`
  - `helm dependency update charts/gitea`
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
- Update golden snapshots after render-impacting changes:
  - `nix-shell -p kubernetes-helm python3Packages.pyyaml --run "./scripts/ci/update_golden.sh"`
- Verify golden snapshots are current:
  - `nix-shell -p kubernetes-helm python3Packages.pyyaml --run "./scripts/ci/check_golden.sh"`

## Change-target rules (charts vs overlays vs docs)
- Change `charts/<service>/` when you need template, chart metadata, image, probes, resources, secret wiring, or service defaults updated for that service.
- Change `charts/platform-stack/` when you need composition, dependency wiring, umbrella defaults, or cross-service orchestration updates.
- Change overlay values files (`charts/platform-stack/values-k3d.yaml` and `charts/platform-stack/values-k3s.yaml`) when behavior must differ by supported target without changing base chart logic.
- Change docs in `docs/` and command references in `README.md` whenever operators must do something new, a default/toggle meaning changes, or validation steps change.
- Do not encode persistent environment decisions only as CLI `--set`; store them in overlay values files.


### Required updates for any render-impacting default changes
When a change affects rendered manifests (especially values that exist in both base service charts and umbrella overrides), update all active layers in one commit to avoid Helm merge drift and repeated golden failures:
- Update every source-of-truth values file that contributes to the same rendered key path (for example both `charts/<service>/values.yaml` and `charts/platform-stack/values.yaml` when both define that subtree).
- Update any bootstrap/config generator defaults that feed those same rendered values.
- Regenerate golden fixtures with `scripts/ci/update_golden.sh` and verify with `scripts/ci/check_golden.sh` before merge.
- If the diff still surprises you, inspect the merged render output first (`./scripts/template.sh ...`) before editing fixtures by hand.

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
  - Run `helm dependency update charts/argo-cd` first when the missing resources involve Argo CD's upstream subchart.
  - Run `helm dependency update charts/gitea` first when the missing resources involve Gitea's upstream subchart.
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
