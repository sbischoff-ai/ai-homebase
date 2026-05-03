# AGENTS.md

## Start here (before editing)
- Read project intent and workflow boundaries: `README.md`.
- Read values layering and target model: `docs/configuration.md`.
- Read service toggles, defaults, and secret contracts: `docs/services.md`.

## Bootstrap-only rule
- Treat this repository as a first-run bootstrap system for a brand-new `ai-homebase` cluster.
- Every script, chart default, seeded file, and helper exists to initialize a fresh installation exactly once before GitOps and the running services take over their own durable state.
- Do not keep backward-compatibility shims, deprecated paths, rerun-preservation behavior, or stale bootstrap code. If a repo-managed bootstrap path is no longer the canonical first-run path, remove it instead of leaving it behind.

## Runtime requirements
- Use the repository's regular `shell.nix` for project runtime requirements. Run project validation and helper commands through `nix-shell --run "<command>"` when required tools such as Helm or Python packages are not already available in the current shell.
- Do not create one-off Nix environments with `nix-shell -p ...` for normal repo tasks. If a regular validation, rendering, test, or bootstrap helper needs an additional runtime dependency, add that dependency to `shell.nix` so every maintainer and future agent gets the same environment.
- Keep command examples in this file and project docs based on `nix-shell --run` against `shell.nix`, not ad hoc package lists.

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
- Update golden snapshots whenever your change modifies rendered manifests for any golden-covered profile (`values`, `values-k3d`, or `values-k3s`):
  - `nix-shell --run "./scripts/ci/update_golden.sh"`
- Verify golden snapshots are current:
  - `nix-shell --run "./scripts/ci/check_golden.sh"`

## Change-target rules (charts vs overlays vs docs)
- Change `charts/<service>/` when you need template, chart metadata, image, probes, resources, secret wiring, or service defaults updated for that service.
- Change `charts/platform-stack/` when you need composition, dependency wiring, umbrella defaults, or cross-service orchestration updates.
- Change overlay values files (`charts/platform-stack/values-k3d.yaml` and `charts/platform-stack/values-k3s.yaml`) when behavior must differ by supported target without changing base chart logic.
- Change docs in `docs/` and command references in `README.md` whenever operators must do something new, a default/toggle meaning changes, or validation steps change.
- Do not encode persistent environment decisions only as CLI `--set`; store them in overlay values files.

## OpenClaw Workspace Files
- When editing `charts/openclaw/files/workspaces/**`, distinguish between repo-maintainer context and the bootstrapped OpenClaw agent's in-cluster perspective.
- Only keep information in seeded workspace files that is useful to the OpenClaw agent at runtime after bootstrap.
- Do not leak editor-facing rationale into those files just because it was useful while making the edit.
- When the official OpenClaw template already establishes the general purpose or wording for a workspace file, adapt that template to this setup instead of inventing repo-local framing.


### Required updates for any render-impacting default changes
When a change affects rendered manifests (especially values that exist in both base service charts and umbrella overrides), update all active layers in one commit to avoid Helm merge drift and repeated golden failures:
- Update every source-of-truth values file that contributes to the same rendered key path (for example both `charts/<service>/values.yaml` and `charts/platform-stack/values.yaml` when both define that subtree).
- Update any bootstrap/config generator defaults that feed those same rendered values.
- Regenerate golden fixtures with `scripts/ci/update_golden.sh` and verify with `scripts/ci/check_golden.sh` before merge.
- If the diff still surprises you, inspect the merged render output first (`./scripts/template.sh ...`) before editing fixtures by hand.

### Golden snapshot trigger rules
Call `scripts/ci/update_golden.sh` in the same change whenever you modify anything that can change Helm render output for the covered profiles. Common triggers include:
- Helm templates, helper templates, `Chart.yaml`, or dependency wiring under `charts/`.
- Any chart `values.yaml`, umbrella values, or supported overlay values (`values-k3d.yaml`, `values-k3s.yaml`).
- Files consumed by templates through `.Files`, ConfigMap/Secret seed content, bootstrap content, or workspace seed files under chart-owned `files/` directories.
- Bootstrap/config-rendering code or defaults that feed Helm values or rendered manifests.
- Service toggles, ingress hosts, secret wiring, init containers, probes, resources, persistence, or image defaults that alter rendered YAML.

Do not skip the update just because the change looks textual. If the output of `./scripts/template.sh ...` would differ, regenerate snapshots.
If you are unsure whether the render changed, run `scripts/ci/check_golden.sh`; if it reports a mismatch and the diff is intentional, run `scripts/ci/update_golden.sh`, then rerun `scripts/ci/check_golden.sh`.

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
