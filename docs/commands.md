# Command reference

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
# Refresh umbrella dependencies when needed
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
  > /tmp/platform-stack-core-only.yaml
```

## CI-equivalent checks

```bash
scripts/ci/lint_all_charts.sh
scripts/ci/render_profiles.sh
python3 scripts/ci/validate_rendered_yaml.py rendered-values.yaml rendered-values-k3d.yaml rendered-values-k3s.yaml
python3 scripts/ci/assert_service_matrix.py
scripts/ci/check_golden.sh
```

## Install wrappers

```bash
./scripts/install.sh --profile k3d
./scripts/install.sh --profile k3s
./scripts/install-k3d.sh
./scripts/install-k3s.sh
```

## Local bootstrap and Incus sandbox helpers

```bash
./scripts/k3d-local-bootstrap.sh --cluster-name ai-homebase-dev
./scripts/incus-vm-up.sh --vm-name openclaw-sandbox
./scripts/incus-vm-down.sh --vm-name openclaw-sandbox
./scripts/k3d-local-teardown.sh --cluster-name ai-homebase-dev --vm-name openclaw-sandbox
./scripts/openclaw-remote-docker-load-images.sh \
  --docker-host ssh://docker-remote@host.k3d.internal:2222 \
  --image openclaw-sandbox:bookworm-slim \
  --image openclaw-sandbox-browser:bookworm-slim
```
