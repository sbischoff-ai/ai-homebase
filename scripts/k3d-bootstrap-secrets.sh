#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/lib/logging.sh"

NAMESPACE="${NAMESPACE:-ai-homebase}"
RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${KUBECONFIG:-}}"
OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-local-dev-token}"
OPENAI_API_KEY="${OPENAI_API_KEY:-}"
REMOTE_DOCKER_SECRET_NAME="${REMOTE_DOCKER_SECRET_NAME:-openclaw-remote-docker-ssh}"
REMOTE_DOCKER_HOST="${REMOTE_DOCKER_HOST:-host.k3d.internal}"
REMOTE_DOCKER_PORT="${REMOTE_DOCKER_PORT:-2222}"
REMOTE_DOCKER_KEY_PATH="${REMOTE_DOCKER_KEY_PATH:-${HOME}/.local/state/ai-homebase/incus/openclaw-sandbox-id_ed25519}"
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
  --openclaw-gateway-token <v>   OpenClaw gateway token (default: ${OPENCLAW_GATEWAY_TOKEN})
  --remote-docker-secret <name>  Secret for OpenClaw remote Docker SSH data (default: ${REMOTE_DOCKER_SECRET_NAME})
  --remote-docker-host <host>    Hostname OpenClaw should use for the SSH-backed Docker endpoint (default: ${REMOTE_DOCKER_HOST})
  --remote-docker-port <port>    SSH port for the remote Docker endpoint (default: ${REMOTE_DOCKER_PORT})
  --remote-docker-key <path>     Private key path generated for the Incus sandbox VM (default: ${REMOTE_DOCKER_KEY_PATH})
  OPENAI_API_KEY env var         Required OpenAI API key for OpenClaw local bootstrap secret
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
    --openclaw-gateway-token) OPENCLAW_GATEWAY_TOKEN="$2"; shift 2 ;;
    --remote-docker-secret) REMOTE_DOCKER_SECRET_NAME="$2"; shift 2 ;;
    --remote-docker-host) REMOTE_DOCKER_HOST="$2"; shift 2 ;;
    --remote-docker-port) REMOTE_DOCKER_PORT="$2"; shift 2 ;;
    --remote-docker-key) REMOTE_DOCKER_KEY_PATH="$2"; shift 2 ;;
    --postgres-admin-password) POSTGRES_ADMIN_PASSWORD="$2"; shift 2 ;;
    --redis-password) REDIS_PASSWORD="$2"; shift 2 ;;
    --verbose) BOOTSTRAP_VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

bootstrap_init_logging
trap 'fail "Bootstrap secrets generation failed. Log: ${BOOTSTRAP_LOG_FILE}"' ERR

for cmd in kubectl openssl ssh-keyscan; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Missing required dependency: $cmd"
    exit 1
  fi
done

if [[ -z "$OPENAI_API_KEY" ]]; then
  fail 'OPENAI_API_KEY is required. Export it before running this script (for example: export OPENAI_API_KEY="sk-...").'
  exit 1
fi

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

create_remote_docker_secret() {
  local secret_name="$1"
  local remote_host="$2"
  local remote_port="$3"
  local key_path="$4"
  local known_hosts_file

  if [[ ! -f "$key_path" ]]; then
    fail "Remote Docker private key not found at ${key_path}. Run ./scripts/incus-vm-up.sh first or pass --remote-docker-key."
    return 1
  fi

  known_hosts_file="$(mktemp)"
  ssh-keyscan -p "$remote_port" "$remote_host" >"$known_hosts_file" 2>>"$BOOTSTRAP_LOG_FILE"

  create_and_apply_secret "$secret_name" \
    --from-file=id_ed25519="$key_path" \
    --from-file=known_hosts="$known_hosts_file"

  rm -f "$known_hosts_file"
}

if [[ -z "$INFISICAL_AUTH_SECRET" ]]; then
  INFISICAL_AUTH_SECRET="$(openssl rand -hex 32)"
fi
if [[ -z "$INFISICAL_ENCRYPTION_KEY" ]]; then
  INFISICAL_ENCRYPTION_KEY="$(generate_infisical_encryption_key)"
fi

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
  --from-literal=OPENCLAW_GATEWAY_TOKEN="$OPENCLAW_GATEWAY_TOKEN" \
  --from-literal=OPENAI_API_KEY="$OPENAI_API_KEY"

create_remote_docker_secret \
  "$REMOTE_DOCKER_SECRET_NAME" \
  "$REMOTE_DOCKER_HOST" \
  "$REMOTE_DOCKER_PORT" \
  "$REMOTE_DOCKER_KEY_PATH"

create_and_apply_secret infisical-secrets \
  --from-literal=AUTH_SECRET="$INFISICAL_AUTH_SECRET" \
  --from-literal=ENCRYPTION_KEY="$INFISICAL_ENCRYPTION_KEY" \
  --from-literal=SITE_URL="$INFISICAL_SITE_URL" \
  --from-literal=DB_CONNECTION_URI="$INFISICAL_DB_URI" \
  --from-literal=REDIS_URL="$INFISICAL_REDIS_URI"

echo "Bootstrap secrets applied in namespace ${NAMESPACE}."
echo "Bootstrap log: ${BOOTSTRAP_LOG_FILE}"
