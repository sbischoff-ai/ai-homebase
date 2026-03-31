# Command reference

> **Canonical source of commands:** Update this file first whenever lint, template, install, CI, or helper-script commands change. Other docs should link here and only keep workflow-specific entry commands.

## Makefile targets

```bash
make help
make lint
make lint-k3d
make lint-k3s
make render > /tmp/platform-stack.yaml
make render-k3d > /tmp/platform-stack-k3d.yaml
make render-k3s > /tmp/platform-stack-k3s.yaml
make smoke-k3d
```

## Canonical lint/template commands

```bash
# Refresh nested Gitea + umbrella dependencies when needed
helm dependency update charts/argo-cd
helm dependency update charts/gitea
helm dependency update charts/platform-stack

# Lint shared defaults
./scripts/lint.sh --values-file charts/platform-stack/values.yaml

# Lint k3d target
./scripts/lint.sh \
  --values-file charts/platform-stack/values.yaml \
  --values-file charts/platform-stack/values-k3d.yaml

# Lint k3s target
./scripts/lint.sh \
  --values-file charts/platform-stack/values.yaml \
  --values-file charts/platform-stack/values-k3s.yaml

# Render shared defaults
./scripts/template.sh \
  --release-name platform-stack \
  --namespace ai-homebase \
  --values-file charts/platform-stack/values.yaml \
  > /tmp/platform-stack.yaml

# Render k3d target
./scripts/template.sh \
  --release-name platform-stack \
  --namespace ai-homebase \
  --values-file charts/platform-stack/values.yaml \
  --values-file charts/platform-stack/values-k3d.yaml \
  > /tmp/platform-stack-k3d.yaml

# Render k3s target
./scripts/template.sh \
  --release-name platform-stack \
  --namespace ai-homebase \
  --values-file charts/platform-stack/values.yaml \
  --values-file charts/platform-stack/values-k3s.yaml \
  > /tmp/platform-stack-k3s.yaml

# Render with explicit service toggle checks
./scripts/template.sh \
  --release-name platform-stack \
  --namespace ai-homebase \
  --values-file charts/platform-stack/values.yaml \
  --disable-service nextcloud \
  --disable-service gitea \
  --disable-service registry \
  > /tmp/platform-stack-core-only.yaml

# Render with cert-manager custom resources explicitly enabled
helm template platform-stack charts/platform-stack \
  --namespace ai-homebase \
  --values charts/platform-stack/values.yaml \
  --set certManager.resourcesEnabled=true \
  > /tmp/platform-stack-with-cert-manager-resources.yaml

# Regression check: rendered manifests must use canonical lowercase cert-manager naming
if rg -n "certManager[A-Z]|cert[-]manager[A-Z]" /tmp/platform-stack-with-cert-manager-resources.yaml; then
  echo "Found legacy or mixed-case cert-manager naming" >&2
  exit 1
fi
```

## CI-equivalent checks

```bash
scripts/ci/lint_all_charts.sh
scripts/ci/render_profiles.sh
python3 scripts/ci/validate_rendered_yaml.py rendered-values.yaml rendered-values-k3d.yaml rendered-values-k3s.yaml
python3 scripts/ci/assert_service_matrix.py
python3 scripts/ci/assert_postgresql_bootstrap_contract.py
scripts/ci/check_golden.sh
```

## Bootstrap flows

```bash
python3 scripts/bootstrap-config.py validate --config bootstrap.local.toml
./scripts/k3d-local-bootstrap.sh --cluster-name ai-homebase-dev --bootstrap-config bootstrap.local.toml
sudo ./scripts/install-k3s-ubuntu-2404.sh
./scripts/k3s-homelab-sandbox-up.sh --bootstrap-config bootstrap.local.toml
./scripts/bootstrap-stack.sh --profile k3s --bootstrap-config bootstrap.local.toml
```

`bootstrap-stack.sh` now includes the GitOps handoff, initial Argo sync, and Argo application validation by default. Re-run `bootstrap-gitops.sh` only when you want to refresh the in-cluster GitOps repo snapshot separately from the main bootstrap flow.

## Local bootstrap and Incus sandbox helpers

```bash
cp bootstrap.example.toml bootstrap.local.toml
python3 scripts/bootstrap-config.py validate --config bootstrap.local.toml
./scripts/k3d-local-bootstrap.sh --cluster-name ai-homebase-dev --bootstrap-config bootstrap.local.toml
./scripts/incus-vm-up.sh --vm-name openclaw-sandbox
# First boot may take several minutes while cloud-init installs Docker Engine and SSH.
# The helper seeds explicit NoCloud user-data + network-config before the VM starts,
# including a default IPv4 route rendered as to: 0.0.0.0/0 for cloud-init/netplan compatibility.
# Override the default 600-second readiness deadline if your host is slower:
SSH_READY_TIMEOUT_SECONDS=900 ./scripts/incus-vm-up.sh --vm-name openclaw-sandbox
source ~/.local/state/ai-homebase/incus/openclaw-sandbox.env
./scripts/bootstrap-stack.sh \
  --profile k3d \
  --namespace ai-homebase \
  --release-name platform-stack \
  --bootstrap-config bootstrap.local.toml \
  --remote-docker-host "$HOST_LISTEN_ADDRESS" \
  --remote-docker-port "$SSH_HOST_PORT" \
  --remote-docker-key ~/.local/state/ai-homebase/incus/openclaw-sandbox-id_ed25519
# Re-running bootstrap-stack refreshes the app secrets, reapplies the chart-managed install flow,
# refreshes the GitOps snapshot, triggers the initial/manual sync step, and validates Argo app state.
# Change bootstrap.local.toml when you intentionally need new hostnames, DB passwords, or admin passwords.
./scripts/incus-vm-down.sh --vm-name openclaw-sandbox
./scripts/k3d-local-teardown.sh --cluster-name ai-homebase-dev --vm-name openclaw-sandbox
# By default, local teardown also removes ~/.local/state/ai-homebase/openclaw-state.
# Use --keep-openclaw-state when you intentionally want to preserve that shared local OpenClaw state.
./scripts/openclaw-remote-docker-load-images.sh \
  --docker-host "ssh://docker-remote@${HOST_LISTEN_ADDRESS}:${SSH_HOST_PORT}" \
  --image openclaw-sandbox:bookworm-slim \
  --image openclaw-sandbox-browser:bookworm-slim
./scripts/build-openclaw-sandbox-images.sh
```

`bootstrap-stack.sh` now auto-builds the repo-managed coder sandbox image and auto-loads it to the remote Docker host when the rendered OpenClaw config references that image. The manual commands above remain useful for debugging or preloading images explicitly.

## Fresh Ubuntu 24.04 `k3s` host prep

```bash
sudo ./scripts/install-k3s-ubuntu-2404.sh
./scripts/k3s-homelab-sandbox-up.sh --bootstrap-config bootstrap.local.toml
```
