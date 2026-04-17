#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/lib/logging.sh"

PROFILE="${PROFILE:-}"
BOOTSTRAP_CONFIG_PATH="${BOOTSTRAP_CONFIG_PATH:-bootstrap.local.toml}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-}"
RAW_KUBECONFIG="${KUBECONFIG:-}"
OPENCLAW_GATEWAY_TOKEN=""
OPENAI_API_KEY=""
ANTHROPIC_API_KEY=""
BRAVE_API_KEY=""
PERPLEXITY_API_KEY=""
GEMINI_API_KEY=""
XAI_API_KEY=""
MOONSHOT_API_KEY=""
GITEA_DB_PASSWORD=""
GITEA_RUNNER_REGISTRATION_TOKEN=""
GITEA_ADMIN_USERNAME=""
GITEA_ADMIN_EMAIL=""
GITEA_ADMIN_PASSWORD=""
VAULTWARDEN_DB_PASSWORD=""
VAULTWARDEN_ADMIN_TOKEN=""
NEXTCLOUD_DB_PASSWORD=""
NEXTCLOUD_ADMIN_PASSWORD=""
OPENCLAW_NEXTCLOUD_MCP_PASSWORD=""
PAPERLESS_DB_PASSWORD=""
PAPERLESS_ADMIN_PASSWORD=""
PAPERLESS_ADMIN_USER=""
PAPERLESS_ADMIN_MAIL=""
PAPERLESS_SECRET_KEY=""
GITHUB_TOKEN=""
REGISTRY_USERNAME=""
REGISTRY_PASSWORD=""
CODER_GITEA_PASSWORD=""
REVIEWER_GITEA_PASSWORD=""
REMOTE_DOCKER_SECRET_NAME="${REMOTE_DOCKER_SECRET_NAME:-openclaw-remote-docker-ssh}"
REMOTE_DOCKER_HOST="${REMOTE_DOCKER_HOST:-}"
REMOTE_DOCKER_PORT="${REMOTE_DOCKER_PORT:-2222}"
REMOTE_DOCKER_KEY_PATH="${REMOTE_DOCKER_KEY_PATH:-${HOME}/.local/state/ai-homebase/incus/openclaw-sandbox-id_ed25519}"
POSTGRES_ADMIN_PASSWORD=""
REDIS_PASSWORD=""
OPENCLAW_PROVIDER_ENV_VARS=(
  OPENAI_API_KEY
  ANTHROPIC_API_KEY
  BRAVE_API_KEY
  PERPLEXITY_API_KEY
  GEMINI_API_KEY
  XAI_API_KEY
  MOONSHOT_API_KEY
)

normalize_kubeconfig_path() {
  local candidate="${1:-}"
  case "$candidate" in
    '${KUBECONFIG:-'*'}')
      candidate="${candidate#'${KUBECONFIG:-'}"
      candidate="${candidate%\}}"
      ;;
    'KUBECONFIG:-'*)
      candidate="${candidate#KUBECONFIG:-}"
      ;;
  esac
  printf '%s' "$candidate"
}

usage() {
  cat <<USAGE
Usage: $0 --profile <k3d|k3s> [options]

Create bootstrap Secrets from a local bootstrap config file.

Options:
  --profile <k3d|k3s>          Supported target profile
  --bootstrap-config <path>    Bootstrap config file (default: ${BOOTSTRAP_CONFIG_PATH})
  --namespace <name>           Target namespace (default: ${NAMESPACE})
  --release-name <name>        Helm release name (default: ${RELEASE_NAME})
  --kubeconfig <path>          Optional kubeconfig path
  --remote-docker-secret <n>   Secret for OpenClaw remote Docker SSH data (default: ${REMOTE_DOCKER_SECRET_NAME})
  --remote-docker-host <host>  Hostname OpenClaw should use for the SSH-backed Docker endpoint (default: ${REMOTE_DOCKER_HOST})
  --remote-docker-port <port>  SSH port for the remote Docker endpoint (default: ${REMOTE_DOCKER_PORT})
  --remote-docker-key <path>   Private key path for the remote Docker Secret (default: ${REMOTE_DOCKER_KEY_PATH})
  --verbose                    Stream full command output
  -h, --help                   Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --bootstrap-config) BOOTSTRAP_CONFIG_PATH="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --release-name) RELEASE_NAME="$2"; shift 2 ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --remote-docker-secret) REMOTE_DOCKER_SECRET_NAME="$2"; shift 2 ;;
    --remote-docker-host) REMOTE_DOCKER_HOST="$2"; shift 2 ;;
    --remote-docker-port) REMOTE_DOCKER_PORT="$2"; shift 2 ;;
    --remote-docker-key) REMOTE_DOCKER_KEY_PATH="$2"; shift 2 ;;
    --verbose) BOOTSTRAP_VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$KUBECONFIG_PATH" ]]; then
  KUBECONFIG_PATH="$(normalize_kubeconfig_path "$RAW_KUBECONFIG")"
fi

case "$PROFILE" in
  k3d|k3s) ;;
  *) echo "Missing or unsupported --profile. Use k3d or k3s." >&2; usage; exit 1 ;;
esac

if [[ -z "$REMOTE_DOCKER_HOST" ]]; then
  case "$PROFILE" in
    k3d) REMOTE_DOCKER_HOST="host.k3d.internal" ;;
    k3s) REMOTE_DOCKER_HOST="openclaw-sandbox.homebase.internal" ;;
  esac
fi

bootstrap_init_logging
trap 'fail "Bootstrap secrets generation failed. Log: ${BOOTSTRAP_LOG_FILE}"' ERR

for cmd in base64 kubectl openssl python3 ssh-keyscan; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Missing required dependency: $cmd"
    exit 1
  fi
done

BOOTSTRAP_SHELL_VARS="$(python3 ./scripts/bootstrap-config.py shell-vars --config "$BOOTSTRAP_CONFIG_PATH")" || exit 1
eval "$BOOTSTRAP_SHELL_VARS"

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

remote_docker_secret_contract_hint() {
  local secret_name="$1"
  printf 'Secret %s must provide non-empty id_ed25519 and known_hosts keys. OpenClaw init will fail if those keys are absent.' "$secret_name"
}

create_remote_docker_secret() {
  local secret_name="$1"
  local remote_host="$2"
  local remote_port="$3"
  local key_path="$4"
  local known_hosts_file

  if [[ ! -s "$key_path" ]]; then
    fail "Remote Docker private key missing or empty at ${key_path}. Run ./scripts/incus-vm-up.sh first or pass --remote-docker-key. $(remote_docker_secret_contract_hint "$secret_name")"
    return 1
  fi

  known_hosts_file="$(mktemp)"
  ssh-keyscan -p "$remote_port" "$remote_host" >"$known_hosts_file" 2>>"$BOOTSTRAP_LOG_FILE" || true

  if [[ ! -s "$known_hosts_file" ]]; then
    rm -f "$known_hosts_file"
    fail "ssh-keyscan did not write known_hosts data for ${remote_host}:${remote_port}. $(remote_docker_secret_contract_hint "$secret_name")"
    return 1
  fi

  create_and_apply_secret "$secret_name" \
    --from-file=id_ed25519="$key_path" \
    --from-file=known_hosts="$known_hosts_file"

  rm -f "$known_hosts_file"
}

generate_secret_hex() {
  local bytes="${1:-24}"
  openssl rand -hex "$bytes"
}

resolve_or_generate() {
  local explicit_value="$1"
  local bytes="${2:-24}"

  if [[ -n "$explicit_value" ]]; then
    printf '%s' "$explicit_value"
    return 0
  fi

  generate_secret_hex "$bytes"
}

resolve_paperless_secret_key() {
  resolve_or_generate "$PAPERLESS_SECRET_KEY" 32
}

generate_htpasswd_entry() {
  local username="$1"
  local password="$2"

  if command -v htpasswd >/dev/null 2>&1; then
    htpasswd -nbB "$username" "$password"
    return 0
  fi

  if command -v docker >/dev/null 2>&1; then
    docker run --rm --entrypoint htpasswd httpd:2.4-alpine -nbB "$username" "$password"
    return 0
  fi

  echo "htpasswd generation requires either the htpasswd CLI or Docker." >&2
  return 1
}

step "Ensuring namespace ${NAMESPACE} exists"
apply_manifest <<MANIFEST
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
MANIFEST

step "Applying bootstrap secrets from ${BOOTSTRAP_CONFIG_PATH}"
OPENCLAW_GATEWAY_TOKEN="$(resolve_or_generate "$OPENCLAW_GATEWAY_TOKEN")"
POSTGRES_ADMIN_PASSWORD="$(resolve_or_generate "$POSTGRES_ADMIN_PASSWORD")"
REDIS_PASSWORD="$(resolve_or_generate "$REDIS_PASSWORD")"
create_and_apply_secret shared-postgresql-auth \
  --from-literal=postgres-password="$POSTGRES_ADMIN_PASSWORD" \
  --from-literal=password="$POSTGRES_ADMIN_PASSWORD"

create_and_apply_secret shared-redis-auth \
  --from-literal=redis-password="$REDIS_PASSWORD"

GITEA_DB_PASSWORD="$(resolve_or_generate "$GITEA_DB_PASSWORD")"
GITEA_RUNNER_REGISTRATION_TOKEN="$(resolve_or_generate "$GITEA_RUNNER_REGISTRATION_TOKEN")"
GITEA_ADMIN_PASSWORD="$(resolve_or_generate "$GITEA_ADMIN_PASSWORD")"
VAULTWARDEN_DB_PASSWORD="$(resolve_or_generate "$VAULTWARDEN_DB_PASSWORD")"
VAULTWARDEN_ADMIN_TOKEN="$(resolve_or_generate "$VAULTWARDEN_ADMIN_TOKEN")"
NEXTCLOUD_DB_PASSWORD="$(resolve_or_generate "$NEXTCLOUD_DB_PASSWORD")"
NEXTCLOUD_ADMIN_PASSWORD="$(resolve_or_generate "$NEXTCLOUD_ADMIN_PASSWORD")"
OPENCLAW_NEXTCLOUD_MCP_PASSWORD="$(resolve_or_generate "$OPENCLAW_NEXTCLOUD_MCP_PASSWORD")"
PAPERLESS_DB_PASSWORD="$(resolve_or_generate "$PAPERLESS_DB_PASSWORD")"
PAPERLESS_ADMIN_PASSWORD="$(resolve_or_generate "$PAPERLESS_ADMIN_PASSWORD")"
PAPERLESS_SECRET_KEY="$(resolve_paperless_secret_key)"
REGISTRY_USERNAME="${REGISTRY_USERNAME:-coder}"
REGISTRY_PASSWORD="$(resolve_or_generate "$REGISTRY_PASSWORD")"
CODER_GITEA_PASSWORD="$(resolve_or_generate "${CODER_GITEA_PASSWORD:-}")"
REVIEWER_GITEA_PASSWORD="$(resolve_or_generate "${REVIEWER_GITEA_PASSWORD:-}")"
GITEA_REDIS_URI="redis://:${REDIS_PASSWORD}@platform-stack-shared-redis:6379/0?pool_size=100&idle_timeout=180s"
PAPERLESS_REDIS_URI="redis://:${REDIS_PASSWORD}@platform-stack-shared-redis:6379/0"
REGISTRY_HTPASSWD="$(generate_htpasswd_entry "$REGISTRY_USERNAME" "$REGISTRY_PASSWORD")"

SHARED_POSTGRESQL_INITDB_SQL="$(mktemp /tmp/ai-homebase-shared-postgresql-initdb.XXXXXX.sql)"
cat >"$SHARED_POSTGRESQL_INITDB_SQL" <<EOF
SELECT format('CREATE ROLE gitea LOGIN PASSWORD %L', '${GITEA_DB_PASSWORD}')
WHERE NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'gitea')\gexec
SELECT format('ALTER ROLE gitea WITH LOGIN PASSWORD %L', '${GITEA_DB_PASSWORD}')
WHERE EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'gitea')\gexec
SELECT 'CREATE DATABASE gitea OWNER gitea'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'gitea')\gexec
ALTER DATABASE gitea OWNER TO gitea;

SELECT format('CREATE ROLE vaultwarden LOGIN PASSWORD %L', '${VAULTWARDEN_DB_PASSWORD}')
WHERE NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'vaultwarden')\gexec
SELECT format('ALTER ROLE vaultwarden WITH LOGIN PASSWORD %L', '${VAULTWARDEN_DB_PASSWORD}')
WHERE EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'vaultwarden')\gexec
SELECT 'CREATE DATABASE vaultwarden OWNER vaultwarden'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'vaultwarden')\gexec
ALTER DATABASE vaultwarden OWNER TO vaultwarden;

SELECT format('CREATE ROLE nextcloud LOGIN PASSWORD %L', '${NEXTCLOUD_DB_PASSWORD}')
WHERE NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'nextcloud')\gexec
SELECT format('ALTER ROLE nextcloud WITH LOGIN PASSWORD %L', '${NEXTCLOUD_DB_PASSWORD}')
WHERE EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'nextcloud')\gexec
SELECT 'CREATE DATABASE nextcloud OWNER nextcloud'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'nextcloud')\gexec
ALTER DATABASE nextcloud OWNER TO nextcloud;

SELECT format('CREATE ROLE paperless LOGIN PASSWORD %L', '${PAPERLESS_DB_PASSWORD}')
WHERE NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'paperless')\gexec
SELECT format('ALTER ROLE paperless WITH LOGIN PASSWORD %L', '${PAPERLESS_DB_PASSWORD}')
WHERE EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'paperless')\gexec
SELECT 'CREATE DATABASE paperless OWNER paperless'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'paperless')\gexec
ALTER DATABASE paperless OWNER TO paperless;
EOF
create_and_apply_secret shared-postgresql-initdb \
  --from-file=10-app-databases.sql="${SHARED_POSTGRESQL_INITDB_SQL}"
rm -f "$SHARED_POSTGRESQL_INITDB_SQL"

create_and_apply_secret gitea-config-secrets \
  --from-literal=GITEA__database__PASSWD="${GITEA_DB_PASSWORD}" \
  --from-literal=GITEA__session__PROVIDER_CONFIG="${GITEA_REDIS_URI}" \
  --from-literal=GITEA__cache__HOST="${GITEA_REDIS_URI}" \
  --from-literal=GITEA__queue__CONN_STR="${GITEA_REDIS_URI}" \
  --from-literal=GITEA__global_lock__SERVICE_CONN_STR="${GITEA_REDIS_URI}" \
  --from-literal=GITEA_RUNNER_REGISTRATION_TOKEN="${GITEA_RUNNER_REGISTRATION_TOKEN}"

create_and_apply_secret gitea-admin-secret \
  --from-literal=username="${GITEA_ADMIN_USERNAME}" \
  --from-literal=password="${GITEA_ADMIN_PASSWORD}" \
  --from-literal=email="${GITEA_ADMIN_EMAIL}"

VAULTWARDEN_SECRET_ARGS=(
  --from-literal=DATABASE_URL="postgresql://vaultwarden:${VAULTWARDEN_DB_PASSWORD}@platform-stack-shared-postgresql:5432/vaultwarden"
  --from-literal=VAULTWARDEN_DB_PASSWORD="${VAULTWARDEN_DB_PASSWORD}"
)
if [[ -n "$VAULTWARDEN_ADMIN_TOKEN" ]]; then
  VAULTWARDEN_SECRET_ARGS+=(--from-literal=ADMIN_TOKEN="${VAULTWARDEN_ADMIN_TOKEN}")
fi
create_and_apply_secret vaultwarden-config-secrets \
  "${VAULTWARDEN_SECRET_ARGS[@]}"

create_and_apply_secret nextcloud-config-secrets \
  --from-literal=NEXTCLOUD_ADMIN_PASSWORD="${NEXTCLOUD_ADMIN_PASSWORD}" \
  --from-literal=POSTGRES_PASSWORD="${NEXTCLOUD_DB_PASSWORD}" \
  --from-literal=REDIS_HOST_PASSWORD="${REDIS_PASSWORD}"

OPENCLAW_NEXTCLOUD_MCP_AUTH_HEADER="Basic $(printf 'openclaw:%s' "${OPENCLAW_NEXTCLOUD_MCP_PASSWORD}" | base64 | tr -d '\n')"
create_and_apply_secret openclaw-nextcloud-mcp-secrets \
  --from-literal=NEXTCLOUD_USERNAME="openclaw" \
  --from-literal=NEXTCLOUD_PASSWORD="${OPENCLAW_NEXTCLOUD_MCP_PASSWORD}" \
  --from-literal=OPENCLAW_NEXTCLOUD_MCP_AUTH_HEADER="${OPENCLAW_NEXTCLOUD_MCP_AUTH_HEADER}"

create_and_apply_secret paperless-config-secrets \
  --from-literal=PAPERLESS_SECRET_KEY="${PAPERLESS_SECRET_KEY}" \
  --from-literal=PAPERLESS_ADMIN_PASSWORD="${PAPERLESS_ADMIN_PASSWORD}" \
  --from-literal=PAPERLESS_DB_PASSWORD="${PAPERLESS_DB_PASSWORD}" \
  --from-literal=PAPERLESS_REDIS="${PAPERLESS_REDIS_URI}"

create_and_apply_secret registry-auth-secret \
  --from-literal=username="${REGISTRY_USERNAME}" \
  --from-literal=password="${REGISTRY_PASSWORD}" \
  --from-literal=htpasswd="${REGISTRY_HTPASSWD}"

create_and_apply_secret coder-credentials \
  --from-literal=CODER_GITEA_PASSWORD="${CODER_GITEA_PASSWORD}" \
  --from-literal=CODER_GITEA_TOKEN="" \
  --from-literal=CODER_REGISTRY_PASSWORD="${REGISTRY_PASSWORD}"

create_and_apply_secret reviewer-credentials \
  --from-literal=REVIEWER_GITEA_PASSWORD="${REVIEWER_GITEA_PASSWORD}" \
  --from-literal=REVIEWER_GITEA_TOKEN=""

OPENCLAW_SECRET_ARGS=(
  --from-literal=OPENCLAW_GATEWAY_TOKEN="$OPENCLAW_GATEWAY_TOKEN"
)
for env_var in "${OPENCLAW_PROVIDER_ENV_VARS[@]}"; do
  if [[ -n "${!env_var:-}" ]]; then
    OPENCLAW_SECRET_ARGS+=(--from-literal="${env_var}=${!env_var}")
  fi
done
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  OPENCLAW_SECRET_ARGS+=(--from-literal="GITHUB_TOKEN=${GITHUB_TOKEN}")
fi
create_and_apply_secret openclaw-secrets \
  "${OPENCLAW_SECRET_ARGS[@]}"

create_remote_docker_secret \
  "$REMOTE_DOCKER_SECRET_NAME" \
  "$REMOTE_DOCKER_HOST" \
  "$REMOTE_DOCKER_PORT" \
  "$REMOTE_DOCKER_KEY_PATH"

echo "Bootstrap secrets applied in namespace ${NAMESPACE}."
echo "Bootstrap log: ${BOOTSTRAP_LOG_FILE}"
