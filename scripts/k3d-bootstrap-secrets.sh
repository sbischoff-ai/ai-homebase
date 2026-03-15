#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/lib/logging.sh"

NAMESPACE="${NAMESPACE:-ai-homebase}"
RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${KUBECONFIG:-}}"
WG_HOST="${WG_HOST:-wg.localtest.me}"
WG_PASSWORD="${WG_PASSWORD:-}"
WG_PASSWORD_OUTPUT_PATH="${WG_PASSWORD_OUTPUT_PATH:-}"
WG_PASSWORD_HASH="${WG_PASSWORD_HASH:-}"
OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-local-dev-token}"
POSTGRES_ADMIN_PASSWORD="${POSTGRES_ADMIN_PASSWORD:-postgres-local-dev}"
REDIS_PASSWORD="${REDIS_PASSWORD:-redis-local-dev}"
INFISICAL_AUTH_SECRET="${INFISICAL_AUTH_SECRET:-}"
INFISICAL_ENCRYPTION_KEY="${INFISICAL_ENCRYPTION_KEY:-}"

usage() {
  cat <<USAGE
Usage: $0 [options]

Create minimal local bootstrap secrets for the k3d profile.

Options:
  --namespace <name>             Target namespace (default: ${NAMESPACE})
  --release-name <name>          Helm release name (default: ${RELEASE_NAME})
  --kubeconfig <path>            Optional kubeconfig path
  --wg-host <host>               WireGuard endpoint host for clients (default: ${WG_HOST})
  --wg-password <password>       wg-easy UI password (auto-generated if omitted; hashed before storing)
  --wg-password-out <path>       Write resolved wg-easy password to file
  --openclaw-gateway-token <v>   OpenClaw gateway token (default: ${OPENCLAW_GATEWAY_TOKEN})
  --postgres-admin-password <v>  shared PostgreSQL admin password (default: generated local value)
  --redis-password <v>           shared Redis password (default: generated local value)
  --verbose                      Stream full command output
  -h, --help                     Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --release-name) RELEASE_NAME="$2"; shift 2 ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --wg-host) WG_HOST="$2"; shift 2 ;;
    --wg-password) WG_PASSWORD="$2"; shift 2 ;;
    --wg-password-out) WG_PASSWORD_OUTPUT_PATH="$2"; shift 2 ;;
    --openclaw-gateway-token) OPENCLAW_GATEWAY_TOKEN="$2"; shift 2 ;;
    --postgres-admin-password) POSTGRES_ADMIN_PASSWORD="$2"; shift 2 ;;
    --redis-password) REDIS_PASSWORD="$2"; shift 2 ;;
    --verbose) BOOTSTRAP_VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

bootstrap_init_logging
trap 'fail "Bootstrap secrets generation failed. Log: ${BOOTSTRAP_LOG_FILE}"' ERR

for cmd in kubectl openssl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Missing required dependency: $cmd"
    exit 1
  fi
done

generate_wg_password_hash() {
  local plain_password="$1"

  if command -v htpasswd >/dev/null 2>&1; then
    htpasswd -bnBC 10 "" "$plain_password" | tr -d ':\n'
    return 0
  fi

  if command -v docker >/dev/null 2>&1; then
    docker run --rm ghcr.io/wg-easy/wg-easy:14 wgpw "$plain_password"
    return 0
  fi

  fail "Unable to generate wg-easy PASSWORD_HASH. Install 'htpasswd' (apache2-utils) or Docker."
  return 1
}

generate_infisical_encryption_key() {
  while true; do
    local candidate
    candidate="$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32)"
    if [[ ${#candidate} -eq 32 ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
}

KUBECTL_ARGS=()
if [[ -n "$KUBECONFIG_PATH" ]]; then
  KUBECTL_ARGS=(--kubeconfig "$KUBECONFIG_PATH")
fi

apply_manifest() {
  local tmp_file
  tmp_file="$(mktemp)"
  cat > "$tmp_file"
  run_quiet kubectl "${KUBECTL_ARGS[@]}" apply -f "$tmp_file"
  rm -f "$tmp_file"
}

create_and_apply_secret() {
  local secret_name="$1"
  shift
  local tmp_file
  local apply_output
  local action_label
  tmp_file="$(mktemp)"
  kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" create secret generic "$secret_name" "$@" --dry-run=client -o yaml > "$tmp_file" 2>>"$BOOTSTRAP_LOG_FILE"

  if [[ "${BOOTSTRAP_VERBOSE:-0}" == "1" ]]; then
    run_verbose kubectl "${KUBECTL_ARGS[@]}" apply -f "$tmp_file"
  else
    apply_output="$(kubectl "${KUBECTL_ARGS[@]}" apply -f "$tmp_file" 2>>"$BOOTSTRAP_LOG_FILE")"
    printf '%s\n' "$apply_output" >>"$BOOTSTRAP_LOG_FILE"

    action_label="updated"
    if [[ "$apply_output" == *" created"* ]]; then
      action_label="created"
    fi

    echo "${action_label} secret ${secret_name}"
  fi

  rm -f "$tmp_file"
}

if [[ -z "$WG_PASSWORD" ]]; then
  WG_PASSWORD="$(openssl rand -hex 12)"
fi

if [[ -z "$WG_PASSWORD_HASH" ]]; then
  WG_PASSWORD_HASH="$(generate_wg_password_hash "$WG_PASSWORD")"
fi

if [[ -z "$INFISICAL_AUTH_SECRET" ]]; then
  INFISICAL_AUTH_SECRET="$(openssl rand -hex 32)"
fi
if [[ -z "$INFISICAL_ENCRYPTION_KEY" ]]; then
  INFISICAL_ENCRYPTION_KEY="$(generate_infisical_encryption_key)"
fi

WG_SECRET_NAME="${RELEASE_NAME}-wg-easy-secrets"
INFISICAL_SITE_URL="http://infisical.localtest.me"
INFISICAL_DB_URI="postgres://postgres:${POSTGRES_ADMIN_PASSWORD}@platform-stack-shared-postgresql:5432/postgres?sslmode=disable"
INFISICAL_REDIS_URI="redis://:${REDIS_PASSWORD}@platform-stack-shared-redis:6379"

step "Ensuring namespace ${NAMESPACE} exists"
apply_manifest <<MANIFEST
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
MANIFEST

step "Applying local bootstrap secrets"
create_and_apply_secret shared-postgresql-auth \
  --from-literal=postgres-password="$POSTGRES_ADMIN_PASSWORD" \
  --from-literal=password="$POSTGRES_ADMIN_PASSWORD"

create_and_apply_secret shared-redis-auth \
  --from-literal=redis-password="$REDIS_PASSWORD"

create_and_apply_secret shared-postgresql-initdb \
  --from-literal=00_bootstrap.sql="-- reserved for local bootstrap init scripts"

create_and_apply_secret openclaw-app-secrets \
  --from-literal=OPENCLAW_GATEWAY_TOKEN="$OPENCLAW_GATEWAY_TOKEN"

create_and_apply_secret "$WG_SECRET_NAME" \
  --from-literal=WG_HOST="$WG_HOST" \
  --from-literal=PASSWORD_HASH="$WG_PASSWORD_HASH"

create_and_apply_secret infisical-secrets \
  --from-literal=AUTH_SECRET="$INFISICAL_AUTH_SECRET" \
  --from-literal=ENCRYPTION_KEY="$INFISICAL_ENCRYPTION_KEY" \
  --from-literal=SITE_URL="$INFISICAL_SITE_URL" \
  --from-literal=DB_CONNECTION_URI="$INFISICAL_DB_URI" \
  --from-literal=REDIS_URL="$INFISICAL_REDIS_URI"

if [[ -n "$WG_PASSWORD_OUTPUT_PATH" ]]; then
  printf '%s\n' "$WG_PASSWORD" > "$WG_PASSWORD_OUTPUT_PATH"
fi

echo "Bootstrap secrets applied in namespace ${NAMESPACE}."
echo "wg-easy secret: ${WG_SECRET_NAME}"
echo "wg-easy UI password: ${WG_PASSWORD}"
echo "Bootstrap log: ${BOOTSTRAP_LOG_FILE}"
