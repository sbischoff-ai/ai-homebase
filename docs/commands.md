# Command reference

Use this page for detailed command recipes. Keep `README.md` focused on quick-start essentials and use this reference for day-to-day operator workflows.

## Makefile targets

`Makefile` wraps common lint/render/smoke commands for `platform-stack`.

```bash
make help
make lint
make lint-k3d
make render > /tmp/platform-stack-dev.yaml
make render-k3d > /tmp/platform-stack-k3d.yaml
make smoke-k3d
```

## Lint/template variants

Canonical lint/render commands with explicit value layering:

```bash
# Refresh umbrella dependencies when needed
helm dependency update charts/platform-stack

# Lint baseline/dev
./scripts/lint.sh --values-file charts/platform-stack/values-dev.yaml

# Lint layered dev + k3d
./scripts/lint.sh \
  --values-file charts/platform-stack/values-dev.yaml \
  --values-file charts/platform-stack/values-k3d.yaml

# Render baseline/dev
./scripts/template.sh \
  --release-name platform-stack \
  --namespace ai-homebase \
  --values-file charts/platform-stack/values-dev.yaml \
  > /tmp/platform-stack-dev.yaml

# Render layered dev + k3d
./scripts/template.sh \
  --release-name platform-stack \
  --namespace ai-homebase \
  --values-file charts/platform-stack/values-dev.yaml \
  --values-file charts/platform-stack/values-k3d.yaml \
  > /tmp/platform-stack-k3d.yaml

# Render with explicit service toggle checks
./scripts/template.sh \
  --release-name platform-stack \
  --namespace ai-homebase \
  --values-file charts/platform-stack/values-dev.yaml \
  --disable-service nextcloud \
  --disable-service gitea \
  > /tmp/platform-stack-core-only.yaml
```

## Render recipes for common exposure postures

These snippets focus on rendered-manifest validation before `helm upgrade --install`.

### 1) Nextcloud enabled + public ingress + TLS

```bash
./scripts/template.sh \
  --release-name platform-stack \
  --namespace ai-homebase \
  --values-file charts/platform-stack/values-dev.yaml \
  --values-file charts/platform-stack/values-homelab-public-nextcloud.yaml \
  > /tmp/platform-stack-homelab-public-nextcloud.yaml

# Verify Nextcloud host/TLS ingress, Service, CronJob, and secret-backed env refs
rg -n "kind: Ingress|platform-stack-nextcloud|cloud.homebase.example.com|nextcloud-tls" /tmp/platform-stack-homelab-public-nextcloud.yaml
rg -n "kind: Service|name: platform-stack-nextcloud" /tmp/platform-stack-homelab-public-nextcloud.yaml
rg -n "kind: CronJob|name: platform-stack-nextcloud-cron" /tmp/platform-stack-homelab-public-nextcloud.yaml
rg -n "POSTGRES_PASSWORD|REDIS_HOST_PASSWORD|nextcloud-app-secrets" /tmp/platform-stack-homelab-public-nextcloud.yaml

# Optional: confirm whether any NetworkPolicy objects are rendered in this profile
rg -n "^kind: NetworkPolicy" /tmp/platform-stack-homelab-public-nextcloud.yaml
```

### 2) Core services VPN-only/internal

```bash
./scripts/template.sh \
  --release-name platform-stack \
  --namespace ai-homebase \
  --values-file charts/platform-stack/values-dev.yaml \
  --disable-service nextcloud \
  --disable-service gitea \
  --disable-service paperless-ngx \
  > /tmp/platform-stack-core-vpn-internal.yaml

# Verify internal ingress host posture and Service objects for core services
rg -n "kind: Ingress|openhands\.vpn\.homebase\.internal|openclaw\.vpn\.homebase\.internal" /tmp/platform-stack-core-vpn-internal.yaml
rg -n "kind: Service|name: platform-stack-openhands|name: platform-stack-openclaw|name: platform-stack-infisical" /tmp/platform-stack-core-vpn-internal.yaml

# Verify Nextcloud objects are absent from this core-only profile
rg -n "platform-stack-nextcloud|cloud\." /tmp/platform-stack-core-vpn-internal.yaml

# Optional: confirm whether any NetworkPolicy objects are rendered in this profile
rg -n "^kind: NetworkPolicy" /tmp/platform-stack-core-vpn-internal.yaml
```

### 3) Nextcloud disabled (explicit check)

```bash
./scripts/template.sh \
  --release-name platform-stack \
  --namespace ai-homebase \
  --values-file charts/platform-stack/values-dev.yaml \
  --disable-service nextcloud \
  > /tmp/platform-stack-no-nextcloud.yaml

# Verify Nextcloud Service, Ingress, and CronJob are not rendered
rg -n "platform-stack-nextcloud|nextcloud-cron|cloud\.localtest\.me" /tmp/platform-stack-no-nextcloud.yaml

# Verify other service secret/env refs still render as expected
rg -n "name: OPENHANDS_|OPENCLAW_|INFISICAL_|WG_|secretKeyRef" /tmp/platform-stack-no-nextcloud.yaml

# Optional: confirm whether any NetworkPolicy objects are rendered in this profile
rg -n "^kind: NetworkPolicy" /tmp/platform-stack-no-nextcloud.yaml
```

`rg` exits with status `1` when no match is found. For absence checks, that `1` exit status is expected and indicates the disabled objects did not render.

## CI-equivalent checks

These local commands mirror repository CI guardrails for chart validity, render checks, and golden fixtures.

```bash
# Lint all chart folders
scripts/ci/lint_all_charts.sh

# Render all supported profiles (plus dev+k3d layering)
scripts/ci/render_profiles.sh

# Validate rendered YAML structure for generated profile files
python3 scripts/ci/validate_rendered_yaml.py rendered-values.yaml rendered-values-dev.yaml rendered-values-aks.yaml rendered-values-prod.yaml rendered-values-dev-k3d.yaml

# Assert service toggle matrix expectations
python3 scripts/ci/assert_service_matrix.py

# Verify golden snapshots are current
scripts/ci/check_golden.sh
```

## Helper scripts

### Local k3d lifecycle

```bash
# Create/prepare local k3d cluster + ingress-nginx
./scripts/k3d-up.sh

# Tear down local k3d cluster
./scripts/k3d-down.sh
```

### Install/upgrade wrappers

```bash
# Install/upgrade dev profile
./scripts/install-dev.sh --values-file charts/platform-stack/values-dev.yaml

# Install/upgrade AKS profile
./scripts/install-aks.sh --values-file charts/platform-stack/values-aks.yaml
```

For script options, run each command with `--help`.
