#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-ai-homebase}"
RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${KUBECONFIG:-}}"
WG_HOST="${WG_HOST:-wg.localtest.me}"
WG_PASSWORD="${WG_PASSWORD:-}"
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
  --wg-password <password>       wg-easy UI password (auto-generated if omitted)
  --openclaw-gateway-token <v>   OpenClaw gateway token (default: ${OPENCLAW_GATEWAY_TOKEN})
  --postgres-admin-password <v>  shared PostgreSQL admin password (default: generated local value)
  --redis-password <v>           shared Redis password (default: generated local value)
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
    --openclaw-gateway-token) OPENCLAW_GATEWAY_TOKEN="$2"; shift 2 ;;
    --postgres-admin-password) POSTGRES_ADMIN_PASSWORD="$2"; shift 2 ;;
    --redis-password) REDIS_PASSWORD="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

for cmd in kubectl openssl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required dependency: $cmd" >&2
    exit 1
  fi
done

KUBECTL_ARGS=()
if [[ -n "$KUBECONFIG_PATH" ]]; then
  KUBECTL_ARGS=(--kubeconfig "$KUBECONFIG_PATH")
fi

if [[ -z "$WG_PASSWORD" ]]; then
  WG_PASSWORD="$(openssl rand -hex 12)"
fi

if [[ -z "$INFISICAL_AUTH_SECRET" ]]; then
  INFISICAL_AUTH_SECRET="$(openssl rand -hex 32)"
fi
if [[ -z "$INFISICAL_ENCRYPTION_KEY" ]]; then
  INFISICAL_ENCRYPTION_KEY="$(openssl rand -hex 32)"
fi

WG_SECRET_NAME="${RELEASE_NAME}-wg-easy-secrets"
INFISICAL_SITE_URL="http://infisical.localtest.me"
INFISICAL_DB_URI="postgres://postgres:${POSTGRES_ADMIN_PASSWORD}@platform-stack-shared-postgresql:5432/postgres?sslmode=disable"
INFISICAL_REDIS_URI="redis://:${REDIS_PASSWORD}@platform-stack-shared-redis:6379"

kubectl "${KUBECTL_ARGS[@]}" create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl "${KUBECTL_ARGS[@]}" apply -f -

kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" create secret generic shared-postgresql-auth \
  --from-literal=postgres-password="$POSTGRES_ADMIN_PASSWORD" \
  --from-literal=password="$POSTGRES_ADMIN_PASSWORD" \
  --dry-run=client -o yaml | kubectl "${KUBECTL_ARGS[@]}" apply -f -

kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" create secret generic shared-redis-auth \
  --from-literal=redis-password="$REDIS_PASSWORD" \
  --dry-run=client -o yaml | kubectl "${KUBECTL_ARGS[@]}" apply -f -

kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" create secret generic shared-postgresql-initdb \
  --from-literal=00_bootstrap.sql="-- reserved for local bootstrap init scripts" \
  --dry-run=client -o yaml | kubectl "${KUBECTL_ARGS[@]}" apply -f -

kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" create secret generic openclaw-app-secrets \
  --from-literal=OPENCLAW_GATEWAY_TOKEN="$OPENCLAW_GATEWAY_TOKEN" \
  --dry-run=client -o yaml | kubectl "${KUBECTL_ARGS[@]}" apply -f -

kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" create secret generic "$WG_SECRET_NAME" \
  --from-literal=WG_HOST="$WG_HOST" \
  --from-literal=PASSWORD="$WG_PASSWORD" \
  --dry-run=client -o yaml | kubectl "${KUBECTL_ARGS[@]}" apply -f -

kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" create secret generic infisical-secrets \
  --from-literal=AUTH_SECRET="$INFISICAL_AUTH_SECRET" \
  --from-literal=ENCRYPTION_KEY="$INFISICAL_ENCRYPTION_KEY" \
  --from-literal=SITE_URL="$INFISICAL_SITE_URL" \
  --from-literal=DB_CONNECTION_URI="$INFISICAL_DB_URI" \
  --from-literal=REDIS_URL="$INFISICAL_REDIS_URI" \
  --dry-run=client -o yaml | kubectl "${KUBECTL_ARGS[@]}" apply -f -

echo "Bootstrap secrets applied in namespace ${NAMESPACE}."
echo "wg-easy secret: ${WG_SECRET_NAME}"
echo "wg-easy UI password: ${WG_PASSWORD}"
