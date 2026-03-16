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

# Create full local bootstrap flow (cluster + secrets + deploy + smoke checks)
./scripts/k3d-local-bootstrap.sh

# Tear down local k3d cluster
./scripts/k3d-down.sh
```

For verbose output from bootstrap helpers, add `--verbose` or set `BOOTSTRAP_VERBOSE=1`.
By default these scripts keep console output concise and write full command logs to `/tmp/ai-homebase-bootstrap-<timestamp>.log`.

## Troubleshooting concise output mode

When running in default concise mode, use this quick workflow to debug failures without switching tools:

- **Log location**: full command logs are written to `/tmp/ai-homebase-bootstrap-<timestamp>.log`.
- **Rerun with verbose output**: add `--verbose` (or set `BOOTSTRAP_VERBOSE=1`) to stream full command output live.
- **Common failure signatures and fixes**:
  - `ERROR: helm dependency build failed` → run `helm dependency update charts/platform-stack` and retry.
  - `ERROR: kubectl cluster-info failed` or `The connection to the server ... was refused` → ensure your target cluster is running and kube context is correct (`kubectl config current-context`).
  - `ERROR: ingress-nginx rollout did not complete` → inspect controller pods/events (`kubectl -n ingress-nginx get pods`, `kubectl -n ingress-nginx describe pod <pod-name>`), then rerun once healthy.
  - `wg-quick up wg0` with `iptables ... can't initialize iptables table 'nat'` → first confirm wg-easy runs as root with `NET_ADMIN`/`SYS_MODULE`, then fix node prerequisites (load `wireguard`, `ip_tables`, `iptable_nat`, usually `iptable_filter`) and confirm `iptables -t nat -L` succeeds on target nodes before redeploying wg-easy. `scripts/k3d-up.sh` now creates k3d nodes with `--privileged@all` and maps `51820/udp` + `51821/tcp` from the server node to reduce nested Docker isolation issues for local WireGuard testing.

### Example concise success transcript

```text
$ ./scripts/k3d-local-bootstrap.sh --cluster-name ai-homebase-dev
[1/7] Checking prerequisites
[2/7] Creating k3d cluster ai-homebase-dev
[3/7] Installing ingress-nginx
[4/7] Validating cluster access
[5/7] Linting chart values
[6/7] Installing platform-stack
[7/7] Running smoke checks
SUCCESS: bootstrap complete
Log file: /tmp/ai-homebase-bootstrap-20260118-103512.log
```

### Example concise failure transcript

```text
$ ./scripts/k3d-local-bootstrap.sh --cluster-name ai-homebase-dev
[1/7] Checking prerequisites
[2/7] Creating k3d cluster ai-homebase-dev
[3/7] Installing ingress-nginx
[4/7] Validating cluster access
ERROR: kubectl cluster-info failed
Hint: rerun with --verbose for full command output
Log file: /tmp/ai-homebase-bootstrap-20260118-104044.log
```

### Install/upgrade wrappers

```bash
# Install/upgrade dev profile
./scripts/install.sh --profile dev --values-file charts/platform-stack/values-dev.yaml

# Install/upgrade AKS profile
./scripts/install.sh --profile aks --values-file charts/platform-stack/values-aks.yaml
```

For script options, run each command with `--help`.
