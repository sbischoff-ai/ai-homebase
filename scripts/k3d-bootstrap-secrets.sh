#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/lib/logging.sh"

NAMESPACE="${NAMESPACE:-ai-homebase}"
RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${KUBECONFIG:-}}"
OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-local-dev-token}"
OPENAI_API_KEY="${OPENAI_API_KEY:-}"
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
BRAVE_API_KEY="${BRAVE_API_KEY:-}"
PERPLEXITY_API_KEY="${PERPLEXITY_API_KEY:-}"
GEMINI_API_KEY="${GEMINI_API_KEY:-}"
XAI_API_KEY="${XAI_API_KEY:-}"
MOONSHOT_API_KEY="${MOONSHOT_API_KEY:-}"
GITEA_DB_PASSWORD="${GITEA_DB_PASSWORD:-}"
VAULTWARDEN_DB_PASSWORD="${VAULTWARDEN_DB_PASSWORD:-}"
REMOTE_DOCKER_SECRET_NAME="${REMOTE_DOCKER_SECRET_NAME:-openclaw-remote-docker-ssh}"
REMOTE_DOCKER_HOST="${REMOTE_DOCKER_HOST:-host.k3d.internal}"
REMOTE_DOCKER_PORT="${REMOTE_DOCKER_PORT:-2222}"
REMOTE_DOCKER_KEY_PATH="${REMOTE_DOCKER_KEY_PATH:-${HOME}/.local/state/ai-homebase/incus/openclaw-sandbox-id_ed25519}"
POSTGRES_ADMIN_PASSWORD="${POSTGRES_ADMIN_PASSWORD:-postgres-local-dev}"
REDIS_PASSWORD="${REDIS_PASSWORD:-redis-local-dev}"
OPENCLAW_PROVIDER_ENV_VARS=(
  OPENAI_API_KEY
  ANTHROPIC_API_KEY
  BRAVE_API_KEY
  PERPLEXITY_API_KEY
  GEMINI_API_KEY
  XAI_API_KEY
  MOONSHOT_API_KEY
)

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
  Provider env vars              At least one supported OpenClaw key is required: OPENAI_API_KEY, ANTHROPIC_API_KEY, BRAVE_API_KEY, PERPLEXITY_API_KEY, GEMINI_API_KEY, XAI_API_KEY, or MOONSHOT_API_KEY
  --postgres-admin-password <v>  shared PostgreSQL admin password (default: generated local value)
  --redis-password <v>           shared Redis password (default: generated local value)
  --gitea-db-password <v>        Gitea database password (default: reuse existing secret value or generate)
  --vaultwarden-db-password <v>  Vaultwarden database password (default: reuse existing secret value or generate)
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
    --gitea-db-password) GITEA_DB_PASSWORD="$2"; shift 2 ;;
    --vaultwarden-db-password) VAULTWARDEN_DB_PASSWORD="$2"; shift 2 ;;
    --verbose) BOOTSTRAP_VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

bootstrap_init_logging
trap 'fail "Bootstrap secrets generation failed. Log: ${BOOTSTRAP_LOG_FILE}"' ERR

for cmd in base64 kubectl openssl ssh-keyscan; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Missing required dependency: $cmd"
    exit 1
  fi
done

has_openclaw_provider_key=0
for env_var in "${OPENCLAW_PROVIDER_ENV_VARS[@]}"; do
  if [[ -n "${!env_var:-}" ]]; then
    has_openclaw_provider_key=1
    break
  fi
done

if [[ "$has_openclaw_provider_key" -eq 0 ]]; then
  fail 'At least one supported OpenClaw provider/search key is required. Export one of OPENAI_API_KEY, ANTHROPIC_API_KEY, BRAVE_API_KEY, PERPLEXITY_API_KEY, GEMINI_API_KEY, XAI_API_KEY, or MOONSHOT_API_KEY before running this script.'
  exit 1
fi

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
  ssh-keyscan -p "$remote_port" "$remote_host" >"$known_hosts_file" 2>>"$BOOTSTRAP_LOG_FILE"

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

wait_for_shared_postgresql_ready() {
  local statefulset_name="$1"
  local pod_name="${statefulset_name}-0"

  step "Waiting for ${pod_name} to become Ready"
  if ! run_quiet kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" wait \
    --for=condition=Ready "pod/${pod_name}" --timeout=180s; then
    fail "Shared PostgreSQL pod ${pod_name} did not become Ready in namespace ${NAMESPACE}; cannot reconcile the live Gitea database bootstrap."
    return 1
  fi
}

reconcile_gitea_postgres_live() {
  local statefulset_name="$1"

  if ! kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" get "statefulset/${statefulset_name}" \
    >/dev/null 2>>"$BOOTSTRAP_LOG_FILE"; then
    return 0
  fi

  wait_for_shared_postgresql_ready "$statefulset_name"

  step "Reconciling live Gitea PostgreSQL role/database on reused cluster"
  if ! run_quiet kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" exec \
    "statefulset/${statefulset_name}" -- env GITEA_DB_PASSWORD="$GITEA_DB_PASSWORD" \
    sh -ceu '
      : "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required in the PostgreSQL container environment}"
      export PGPASSWORD="${POSTGRES_PASSWORD}"
      psql -v ON_ERROR_STOP=1 \
        --username "${POSTGRES_USER:-postgres}" \
        --dbname postgres \
        --set=gitea_db_password="$GITEA_DB_PASSWORD" <<'"'"'SQL'"'"'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '"'"'gitea'"'"') THEN
    EXECUTE format('"'"'CREATE ROLE gitea LOGIN PASSWORD %L'"'"', :'gitea_db_password');
  ELSE
    EXECUTE format('"'"'ALTER ROLE gitea WITH LOGIN PASSWORD %L'"'"', :'gitea_db_password');
  END IF;
END
$$;
SELECT '"'"'CREATE DATABASE gitea OWNER gitea'"'"'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '"'"'gitea'"'"')\gexec
ALTER DATABASE gitea OWNER TO gitea;
SQL
    '; then
    fail "Unable to reconcile the live Gitea PostgreSQL role/database in ${NAMESPACE}. Check connectivity to ${statefulset_name} and inspect ${BOOTSTRAP_LOG_FILE}."
    return 1
  fi

  ok "Reconciled live Gitea PostgreSQL role/database"
}

resolve_gitea_db_password() {
  local existing_password_b64=""

  if [[ -n "$GITEA_DB_PASSWORD" ]]; then
    printf '%s' "$GITEA_DB_PASSWORD"
    return 0
  fi

  existing_password_b64="$(
    kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" get secret gitea-config-secrets \
      -o jsonpath='{.data.GITEA__database__PASSWD}' 2>>"$BOOTSTRAP_LOG_FILE" || true
  )"
  if [[ -n "$existing_password_b64" ]]; then
    printf '%s' "$existing_password_b64" | base64 --decode
    return 0
  fi

  openssl rand -hex 24
}

resolve_vaultwarden_db_password() {
  local existing_database_url_b64=""

  if [[ -n "$VAULTWARDEN_DB_PASSWORD" ]]; then
    printf '%s' "$VAULTWARDEN_DB_PASSWORD"
    return 0
  fi

  existing_database_url_b64="$(
    kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" get secret vaultwarden-config-secrets \
      -o jsonpath='{.data.DATABASE_URL}' 2>>"$BOOTSTRAP_LOG_FILE" || true
  )"
  if [[ -n "$existing_database_url_b64" ]]; then
    printf '%s' "$existing_database_url_b64" | base64 --decode | python3 -c '
import sys
from urllib.parse import unquote, urlparse

database_url = sys.stdin.read().strip()
parsed = urlparse(database_url)
if parsed.password is None:
    raise SystemExit(1)
print(unquote(parsed.password), end="")
'
    return 0
  fi

  openssl rand -hex 24
}

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

GITEA_DB_PASSWORD="$(resolve_gitea_db_password)"
VAULTWARDEN_DB_PASSWORD="$(resolve_vaultwarden_db_password)"
GITEA_DB_PASSWORD_SHELL_QUOTED="$(printf '%q' "$GITEA_DB_PASSWORD")"
VAULTWARDEN_DB_PASSWORD_SHELL_QUOTED="$(printf '%q' "$VAULTWARDEN_DB_PASSWORD")"
GITEA_REDIS_URI="redis://:${REDIS_PASSWORD}@platform-stack-shared-redis:6379/0?pool_size=100&idle_timeout=180s"
GITEA_INITDB_SCRIPT="$(mktemp)"
cat >"${GITEA_INITDB_SCRIPT}" <<EOF
#!/bin/sh
set -eu
export GITEA_DB_PASSWORD=${GITEA_DB_PASSWORD_SHELL_QUOTED}
export VAULTWARDEN_DB_PASSWORD=${VAULTWARDEN_DB_PASSWORD_SHELL_QUOTED}
psql -v ON_ERROR_STOP=1 \
  --username "\${POSTGRES_USER:-postgres}" \
  --dbname postgres \
  --set=gitea_db_password="\${GITEA_DB_PASSWORD}" \
  --set=vaultwarden_db_password="\${VAULTWARDEN_DB_PASSWORD}" <<'SQL'
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'gitea') THEN
    EXECUTE format('CREATE ROLE gitea LOGIN PASSWORD %L', :'gitea_db_password');
  ELSE
    EXECUTE format('ALTER ROLE gitea WITH LOGIN PASSWORD %L', :'gitea_db_password');
  END IF;

  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'vaultwarden') THEN
    EXECUTE format('CREATE ROLE vaultwarden LOGIN PASSWORD %L', :'vaultwarden_db_password');
  ELSE
    EXECUTE format('ALTER ROLE vaultwarden WITH LOGIN PASSWORD %L', :'vaultwarden_db_password');
  END IF;
END
\$\$;
SQL
if [ "\$(psql -v ON_ERROR_STOP=1 --username "\${POSTGRES_USER:-postgres}" --dbname postgres -tAc "SELECT 1 FROM pg_database WHERE datname = 'gitea'")" != "1" ]; then
  psql -v ON_ERROR_STOP=1 --username "\${POSTGRES_USER:-postgres}" --dbname postgres -c "CREATE DATABASE gitea OWNER gitea"
fi
psql -v ON_ERROR_STOP=1 --username "\${POSTGRES_USER:-postgres}" --dbname postgres -c "ALTER DATABASE gitea OWNER TO gitea"
if [ "\$(psql -v ON_ERROR_STOP=1 --username "\${POSTGRES_USER:-postgres}" --dbname postgres -tAc "SELECT 1 FROM pg_database WHERE datname = 'vaultwarden'")" != "1" ]; then
  psql -v ON_ERROR_STOP=1 --username "\${POSTGRES_USER:-postgres}" --dbname postgres -c "CREATE DATABASE vaultwarden OWNER vaultwarden"
fi
psql -v ON_ERROR_STOP=1 --username "\${POSTGRES_USER:-postgres}" --dbname postgres -c "ALTER DATABASE vaultwarden OWNER TO vaultwarden"
EOF

create_and_apply_secret shared-postgresql-initdb \
  --from-file=00_bootstrap.sh="${GITEA_INITDB_SCRIPT}"
rm -f "${GITEA_INITDB_SCRIPT}"

create_and_apply_secret gitea-config-secrets \
  --from-literal=GITEA__database__PASSWD="${GITEA_DB_PASSWORD}" \
  --from-literal=GITEA__session__PROVIDER_CONFIG="${GITEA_REDIS_URI}" \
  --from-literal=GITEA__cache__HOST="${GITEA_REDIS_URI}" \
  --from-literal=GITEA__queue__CONN_STR="${GITEA_REDIS_URI}" \
  --from-literal=GITEA__global_lock__SERVICE_CONN_STR="${GITEA_REDIS_URI}"

reconcile_gitea_postgres_live "${RELEASE_NAME}-shared-postgresql"

create_and_apply_secret vaultwarden-config-secrets \
  --from-literal=DATABASE_URL="postgresql://vaultwarden:${VAULTWARDEN_DB_PASSWORD}@platform-stack-shared-postgresql:5432/vaultwarden"

OPENCLAW_SECRET_ARGS=(
  --from-literal=OPENCLAW_GATEWAY_TOKEN="$OPENCLAW_GATEWAY_TOKEN"
)
for env_var in "${OPENCLAW_PROVIDER_ENV_VARS[@]}"; do
  if [[ -n "${!env_var:-}" ]]; then
    OPENCLAW_SECRET_ARGS+=(--from-literal="${env_var}=${!env_var}")
  fi
done
create_and_apply_secret openclaw-app-secrets \
  "${OPENCLAW_SECRET_ARGS[@]}"

create_remote_docker_secret \
  "$REMOTE_DOCKER_SECRET_NAME" \
  "$REMOTE_DOCKER_HOST" \
  "$REMOTE_DOCKER_PORT" \
  "$REMOTE_DOCKER_KEY_PATH"


echo "Bootstrap secrets applied in namespace ${NAMESPACE}."
echo "Bootstrap log: ${BOOTSTRAP_LOG_FILE}"
