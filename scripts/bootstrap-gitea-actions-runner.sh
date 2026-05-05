#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/lib/logging.sh"

BOOTSTRAP_CONFIG_PATH="${BOOTSTRAP_CONFIG_PATH:-bootstrap.local.toml}"
RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-}"
RAW_KUBECONFIG="${KUBECONFIG:-}"
RUNNER_VM_NAME="${RUNNER_VM_NAME:-gitea-actions-runner}"
RUNNER_CONNECTION_INFO_PATH="${RUNNER_CONNECTION_INFO_PATH:-}"
RUNNER_KEY_PATH="${RUNNER_KEY_PATH:-}"

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
Usage: $0 [options]

Bootstrap the dedicated Gitea Actions runner on its companion VM.

Options:
  --bootstrap-config <path>    Bootstrap config file (default: ${BOOTSTRAP_CONFIG_PATH})
  --release-name <name>        Helm release name (default: ${RELEASE_NAME})
  --namespace <name>           Kubernetes namespace (default: ${NAMESPACE})
  --kubeconfig <path>          Optional kubeconfig path
  --runner-vm-name <name>      Incus runner VM name (default: ${RUNNER_VM_NAME})
  --runner-connection-info <p> Runner VM connection info env file
  --runner-key <path>          SSH private key for the runner VM
  --verbose                    Stream full command output
  -h, --help                   Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap-config) BOOTSTRAP_CONFIG_PATH="$2"; shift 2 ;;
    --release-name) RELEASE_NAME="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --runner-vm-name) RUNNER_VM_NAME="$2"; shift 2 ;;
    --runner-connection-info) RUNNER_CONNECTION_INFO_PATH="$2"; shift 2 ;;
    --runner-key) RUNNER_KEY_PATH="$2"; shift 2 ;;
    --verbose) BOOTSTRAP_VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$KUBECONFIG_PATH" ]]; then
  KUBECONFIG_PATH="$(normalize_kubeconfig_path "$RAW_KUBECONFIG")"
fi

bootstrap_init_logging
trap 'fail "Gitea Actions runner bootstrap failed. Log: ${BOOTSTRAP_LOG_FILE}"' ERR

for cmd in base64 curl kubectl python3 scp ssh ssh-keyscan; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Missing required dependency: $cmd"
    exit 1
  fi
done

BOOTSTRAP_SHELL_VARS="$(python3 ./scripts/bootstrap-config.py shell-vars --config "$BOOTSTRAP_CONFIG_PATH")" || exit 1
eval "$BOOTSTRAP_SHELL_VARS"

if [[ "${GITEA_ACTIONS_ENABLED:-false}" != "true" ]]; then
  echo "Gitea Actions are disabled; skipping runner bootstrap."
  exit 0
fi

RUNNER_VM_NAME="${GITEA_ACTIONS_RUNNER_VM_NAME:-$RUNNER_VM_NAME}"
if [[ -z "$RUNNER_CONNECTION_INFO_PATH" ]]; then
  RUNNER_CONNECTION_INFO_PATH="${HOME}/.local/state/ai-homebase/incus/${RUNNER_VM_NAME}.env"
fi
if [[ -z "$RUNNER_KEY_PATH" ]]; then
  RUNNER_KEY_PATH="${HOME}/.local/state/ai-homebase/incus/${RUNNER_VM_NAME}-id_ed25519"
fi

if [[ ! -f "$RUNNER_CONNECTION_INFO_PATH" ]]; then
  fail "Runner connection info not found: ${RUNNER_CONNECTION_INFO_PATH}. Bootstrap the runner VM first."
  exit 1
fi
if [[ ! -s "$RUNNER_KEY_PATH" ]]; then
  fail "Runner SSH key missing or empty: ${RUNNER_KEY_PATH}."
  exit 1
fi

# shellcheck disable=SC1090
source "$RUNNER_CONNECTION_INFO_PATH"

if [[ -z "${HOST_LISTEN_ADDRESS:-}" || -z "${SSH_HOST_PORT:-}" || -z "${REMOTE_USER:-}" ]]; then
  fail "Runner connection info ${RUNNER_CONNECTION_INFO_PATH} is missing HOST_LISTEN_ADDRESS, SSH_HOST_PORT, or REMOTE_USER."
  exit 1
fi

KUBECTL_ARGS=()
if [[ -n "$KUBECONFIG_PATH" ]]; then
  KUBECTL_ARGS=(--kubeconfig "$KUBECONFIG_PATH")
fi

runner_registration_token="$(kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" get secret gitea-config-secrets -o jsonpath='{.data.GITEA_RUNNER_REGISTRATION_TOKEN}' | base64 -d)"
if [[ -z "$runner_registration_token" ]]; then
  fail "Gitea runner registration token is empty in secret/gitea-config-secrets."
  exit 1
fi
registry_username="$(kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" get secret registry-auth-secret -o jsonpath='{.data.username}' | base64 -d)"
registry_password="$(kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" get secret registry-auth-secret -o jsonpath='{.data.password}' | base64 -d)"
if [[ -z "${REGISTRY_HOST:-}" || -z "$registry_username" || -z "$registry_password" ]]; then
  fail "Registry credentials or REGISTRY_HOST are unavailable for the Gitea Actions runner bootstrap."
  exit 1
fi

gitea_instance_url="${GITEA_BASE_URL:-}"
if [[ -z "$gitea_instance_url" ]]; then
  fail "GITEA_BASE_URL is unavailable for the Gitea Actions runner bootstrap."
  exit 1
fi
runner_name="${RELEASE_NAME}-${RUNNER_VM_NAME}"
runner_container_name="gitea-actions-runner"
runner_root_dir="/opt/ai-homebase/gitea-actions-runner"
runner_data_dir="/var/lib/ai-homebase/gitea-actions-runner"
runner_labels="${GITEA_ACTIONS_RUNNER_LABELS}"
runner_image="docker.io/gitea/act_runner:latest"
job_image="${GITEA_ACTIONS_JOB_IMAGE}"
runner_env_file_local="$(mktemp /tmp/ai-homebase-gitea-actions-runner-env.XXXXXX)"
runner_bootstrap_local="$(mktemp /tmp/ai-homebase-gitea-actions-runner-bootstrap.XXXXXX.sh)"
runner_docker_config_local="$(mktemp /tmp/ai-homebase-gitea-actions-runner-docker-config.XXXXXX.json)"
known_hosts_file="$(mktemp /tmp/ai-homebase-gitea-actions-runner-known-hosts.XXXXXX)"

cleanup() {
  rm -f "$runner_env_file_local" "$runner_bootstrap_local" "$runner_docker_config_local" "$known_hosts_file"
}
trap cleanup EXIT

ssh-keyscan -p "$SSH_HOST_PORT" "$HOST_LISTEN_ADDRESS" >"$known_hosts_file" 2>>"$BOOTSTRAP_LOG_FILE" || true
if [[ ! -s "$known_hosts_file" ]]; then
  fail "ssh-keyscan did not return host keys for runner VM ${HOST_LISTEN_ADDRESS}:${SSH_HOST_PORT}."
  exit 1
fi

cat >"$runner_env_file_local" <<EOF
GITEA_INSTANCE_URL=${gitea_instance_url}
GITEA_RUNNER_REGISTRATION_TOKEN=${runner_registration_token}
GITEA_RUNNER_NAME=${runner_name}
GITEA_RUNNER_LABELS=${runner_labels}
CONFIG_FILE=/config.yaml
SSL_CERT_FILE=/etc/ssl/certs/ai-homebase-root-ca.crt
REQUESTS_CA_BUNDLE=/etc/ssl/certs/ai-homebase-root-ca.crt
NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ai-homebase-root-ca.crt
GIT_SSL_CAINFO=/etc/ssl/certs/ai-homebase-root-ca.crt
CURL_CA_BUNDLE=/etc/ssl/certs/ai-homebase-root-ca.crt
EOF

registry_auth="$(printf '%s:%s' "$registry_username" "$registry_password" | base64 | tr -d '\n')"
cat >"$runner_docker_config_local" <<EOF
{
  "auths": {
    "${REGISTRY_HOST}": {
      "auth": "${registry_auth}"
    },
    "https://${REGISTRY_HOST}": {
      "auth": "${registry_auth}"
    }
  }
}
EOF

cat >"$runner_bootstrap_local" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

runner_root_dir="${RUNNER_ROOT_DIR:?}"
runner_data_dir="${RUNNER_DATA_DIR:?}"
runner_container_name="${RUNNER_CONTAINER_NAME:?}"
runner_image="${RUNNER_IMAGE:?}"
runner_labels="${RUNNER_LABELS:?}"
job_image="${JOB_IMAGE:?}"

mkdir -p "${runner_root_dir}" "${runner_data_dir}/data"
chmod 0755 "${runner_root_dir}" "${runner_data_dir}"

docker pull "${runner_image}" >/dev/null
docker run --rm --entrypoint "" "${runner_image}" act_runner generate-config > "${runner_root_dir}/config.yaml"
python3 - "${runner_root_dir}/config.yaml" "${runner_labels}" <<'PY'
from pathlib import Path
import sys

config_path = Path(sys.argv[1])
labels = [label.strip() for label in sys.argv[2].split(",") if label.strip()]
lines = config_path.read_text().splitlines()
updated = []
in_labels = False

for line in lines:
    if in_labels:
        if line.startswith("    - "):
            continue
        in_labels = False
    if line == "  file: .runner":
        updated.append("  file: /data/.runner")
        continue
    if line == "  labels:":
        updated.append(line)
        for label in labels:
          updated.append(f'    - "{label}"')
        in_labels = True
        continue
    updated.append(line)

config_path.write_text("\n".join(updated) + "\n")
PY
docker rm -f "${runner_container_name}" >/dev/null 2>&1 || true
rm -f "${runner_data_dir}/data/.runner"
DOCKER_CONFIG="${runner_root_dir}/docker-config" docker pull "${job_image}" >/dev/null

docker run -d \
  --name "${runner_container_name}" \
  --restart unless-stopped \
  --env-file "${runner_root_dir}/runner.env" \
  -e DOCKER_CONFIG=/root/.docker \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "${runner_root_dir}/config.yaml:/config.yaml:ro" \
  -v "${runner_root_dir}/docker-config:/root/.docker:ro" \
  -v "${runner_data_dir}/data:/data" \
  -v /usr/local/share/ca-certificates/ai-homebase-root-ca.crt:/etc/ssl/certs/ai-homebase-root-ca.crt:ro \
  "${runner_image}" >/dev/null

docker inspect "${runner_container_name}" >/dev/null
EOF

runner_ssh() {
  ssh \
    -i "$RUNNER_KEY_PATH" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=yes \
    -o "UserKnownHostsFile=${known_hosts_file}" \
    -o GlobalKnownHostsFile=/dev/null \
    -p "$SSH_HOST_PORT" \
    "${REMOTE_USER}@${HOST_LISTEN_ADDRESS}" \
    "$@"
}

runner_scp() {
  scp \
    -i "$RUNNER_KEY_PATH" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=yes \
    -o "UserKnownHostsFile=${known_hosts_file}" \
    -o GlobalKnownHostsFile=/dev/null \
    -P "$SSH_HOST_PORT" \
    "$1" "${REMOTE_USER}@${HOST_LISTEN_ADDRESS}:$2"
}

step "Preparing Gitea Actions runner assets on ${RUNNER_VM_NAME}"
runner_ssh "sudo install -d -m 0755 -o '${REMOTE_USER}' -g '${REMOTE_USER}' '${runner_root_dir}' '${runner_root_dir}/docker-config' '${runner_data_dir}' '${runner_data_dir}/data'"
runner_scp "$runner_env_file_local" "${runner_root_dir}/runner.env"
runner_scp "$runner_bootstrap_local" "${runner_root_dir}/bootstrap-runner.sh"
runner_scp "$runner_docker_config_local" "${runner_root_dir}/docker-config/config.json"
runner_ssh "chmod 0755 '${runner_root_dir}/bootstrap-runner.sh'"

step "Starting Gitea Actions runner container on ${RUNNER_VM_NAME}"
runner_ssh \
  "RUNNER_ROOT_DIR='${runner_root_dir}' RUNNER_DATA_DIR='${runner_data_dir}' RUNNER_CONTAINER_NAME='${runner_container_name}' RUNNER_IMAGE='${runner_image}' RUNNER_LABELS='${runner_labels}' JOB_IMAGE='${job_image}' '${runner_root_dir}/bootstrap-runner.sh'"

ok "Gitea Actions runner container is bootstrapped on ${RUNNER_VM_NAME}"
