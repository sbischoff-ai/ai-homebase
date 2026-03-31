#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/lib/logging.sh"

CLUSTER_NAME="${CLUSTER_NAME:-ai-homebase-dev}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${HOME}/.kube/k3d-${CLUSTER_NAME}.yaml}"
BOOTSTRAP_CONFIG_PATH="${BOOTSTRAP_CONFIG_PATH:-bootstrap.local.toml}"
INCUS_VM_NAME="${INCUS_VM_NAME:-openclaw-sandbox}"
SHARED_OPENCLAW_STATE_SOURCE="${SHARED_OPENCLAW_STATE_SOURCE:-${HOME}/.local/state/ai-homebase/openclaw-state}"
SHARED_OPENCLAW_STATE_NODE_PATH="${SHARED_OPENCLAW_STATE_NODE_PATH:-/var/lib/ai-homebase/openclaw-state}"
SHARED_OPENCLAW_STATE_VM_PATH="${SHARED_OPENCLAW_STATE_VM_PATH:-/home/node/.openclaw}"
REMOTE_DOCKER_HOST="${REMOTE_DOCKER_HOST:-host.k3d.internal}"
REMOTE_DOCKER_PORT="${REMOTE_DOCKER_PORT:-2222}"
REMOTE_DOCKER_KEY_PATH="${REMOTE_DOCKER_KEY_PATH:-${HOME}/.local/state/ai-homebase/incus/${INCUS_VM_NAME}-id_ed25519}"
INCUS_CONNECTION_INFO_PATH="${INCUS_CONNECTION_INFO_PATH:-}"
REMOTE_DOCKER_HOST_EXPLICIT=0
REMOTE_DOCKER_PORT_EXPLICIT=0
OPENCLAW_GATEWAY_TOKEN_VALUE=""
OPENCLAW_MAIN_MODEL=""
OPENCLAW_CODER_MODEL=""
OPENCLAW_ARCHITECT_MODEL=""
OPENCLAW_HOST_VALUE="openclaw.localtest.me"
NEXTCLOUD_HOST_VALUE="nextcloud.localtest.me"
GITEA_HOST_VALUE="gitea.localtest.me"
REGISTRY_HOST_VALUE="registry.localtest.me"
VAULTWARDEN_HOST_VALUE="vaultwarden.localtest.me"
PAPERLESS_HOST_VALUE="paperless.localtest.me"
NEXTCLOUD_MCP_HOST_VALUE="nextcloud-mcp.localtest.me"
QDRANT_MCP_HOST_VALUE="qdrant-mcp.localtest.me"

usage() {
  cat <<USAGE
Usage: $0 [options]

End-to-end local bootstrap for k3d: cluster + ingress-nginx + bootstrap config + secrets + deploy + smoke checks.

Options:
  --cluster-name <name>    k3d cluster name (default: ${CLUSTER_NAME})
  --namespace <name>       Kubernetes namespace (default: ${NAMESPACE})
  --release-name <name>    Helm release name (default: ${RELEASE_NAME})
  --kubeconfig <path>      Dedicated kubeconfig path (default: ${KUBECONFIG_PATH})
  --bootstrap-config <p>   Bootstrap config file (default: ${BOOTSTRAP_CONFIG_PATH})
  --incus-vm-name <name>   Incus VM name for the remote Docker sandbox (default: ${INCUS_VM_NAME})
  --shared-openclaw-state-source <path>
                           Host path shared between k3d nodes and the sandbox VM for OpenClaw state (default: ${SHARED_OPENCLAW_STATE_SOURCE})
  --remote-docker-host <h> Hostname OpenClaw should use for the remote Docker SSH endpoint (default: ${REMOTE_DOCKER_HOST})
  --remote-docker-port <p> SSH port for the remote Docker endpoint (default: ${REMOTE_DOCKER_PORT})
  --remote-docker-key <p>  Private key path for the OpenClaw remote Docker Secret (default: ${REMOTE_DOCKER_KEY_PATH})
  --incus-connection-info <p> Path to the Incus VM connection info env file (default: ${INCUS_CONNECTION_INFO_PATH})
  --verbose                Stream full command output
  -h, --help               Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster-name) CLUSTER_NAME="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --release-name) RELEASE_NAME="$2"; shift 2 ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --bootstrap-config) BOOTSTRAP_CONFIG_PATH="$2"; shift 2 ;;
    --incus-vm-name) INCUS_VM_NAME="$2"; shift 2 ;;
    --shared-openclaw-state-source) SHARED_OPENCLAW_STATE_SOURCE="$2"; shift 2 ;;
    --remote-docker-host) REMOTE_DOCKER_HOST="$2"; REMOTE_DOCKER_HOST_EXPLICIT=1; shift 2 ;;
    --remote-docker-port) REMOTE_DOCKER_PORT="$2"; REMOTE_DOCKER_PORT_EXPLICIT=1; shift 2 ;;
    --remote-docker-key) REMOTE_DOCKER_KEY_PATH="$2"; shift 2 ;;
    --incus-connection-info) INCUS_CONNECTION_INFO_PATH="$2"; shift 2 ;;
    --verbose) BOOTSTRAP_VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$INCUS_CONNECTION_INFO_PATH" ]]; then
  INCUS_CONNECTION_INFO_PATH="${HOME}/.local/state/ai-homebase/incus/${INCUS_VM_NAME}.env"
fi

bootstrap_init_logging
export KUBECONFIG="$KUBECONFIG_PATH"
on_error() {
  fail "Local bootstrap failed."
  echo
  echo "Summary:"
  echo "  Kubeconfig: ${KUBECONFIG}"
  echo "  Bootstrap log: ${BOOTSTRAP_LOG_FILE}"
}
trap on_error ERR

BOOTSTRAP_SHELL_VARS="$(python3 ./scripts/bootstrap-config.py shell-vars --config "$BOOTSTRAP_CONFIG_PATH")" || exit 1
eval "$BOOTSTRAP_SHELL_VARS"
OPENCLAW_GATEWAY_TOKEN_VALUE="${OPENCLAW_GATEWAY_TOKEN:-local-dev-token}"
OPENCLAW_MAIN_MODEL="${OPENCLAW_MAIN_MODEL:-}"
OPENCLAW_CODER_MODEL="${OPENCLAW_CODER_MODEL:-}"
OPENCLAW_ARCHITECT_MODEL="${OPENCLAW_ARCHITECT_MODEL:-}"
OPENCLAW_HOST_VALUE="${OPENCLAW_HOST:-${OPENCLAW_HOST_VALUE}}"
NEXTCLOUD_HOST_VALUE="${NEXTCLOUD_HOST:-${NEXTCLOUD_HOST_VALUE}}"
GITEA_HOST_VALUE="${GITEA_HOST:-${GITEA_HOST_VALUE}}"
REGISTRY_HOST_VALUE="${REGISTRY_HOST:-${REGISTRY_HOST_VALUE}}"
VAULTWARDEN_HOST_VALUE="${VAULTWARDEN_HOST:-${VAULTWARDEN_HOST_VALUE}}"
PAPERLESS_HOST_VALUE="${PAPERLESS_HOST:-${PAPERLESS_HOST_VALUE}}"
NEXTCLOUD_MCP_HOST_VALUE="${NEXTCLOUD_MCP_HOST:-${NEXTCLOUD_MCP_HOST_VALUE}}"
QDRANT_MCP_HOST_VALUE="${QDRANT_MCP_HOST:-${QDRANT_MCP_HOST_VALUE}}"

step "Bootstrapping k3d cluster and ingress"
K3D_UP_CMD=(
  ./scripts/k3d-up.sh
  --cluster-name "$CLUSTER_NAME"
  --kubeconfig "$KUBECONFIG_PATH"
  --shared-openclaw-state-source "$SHARED_OPENCLAW_STATE_SOURCE"
  --shared-openclaw-state-target "$SHARED_OPENCLAW_STATE_NODE_PATH"
)

run_quiet "${K3D_UP_CMD[@]}"
ok "Cluster is ready"

step "Bootstrapping Incus sandbox VM"
run_quiet ./scripts/incus-vm-up.sh \
  --vm-name "$INCUS_VM_NAME" \
  --shared-openclaw-state-source "$SHARED_OPENCLAW_STATE_SOURCE" \
  --shared-openclaw-state-target "$SHARED_OPENCLAW_STATE_VM_PATH" \
  --resolve-host "$OPENCLAW_HOST_VALUE" \
  --resolve-host "$NEXTCLOUD_MCP_HOST_VALUE" \
  --resolve-host "$QDRANT_MCP_HOST_VALUE" \
  --resolve-host "$GITEA_HOST_VALUE" \
  --resolve-host "$REGISTRY_HOST_VALUE"
ok "Incus sandbox VM is ready"

if [[ -f "$INCUS_CONNECTION_INFO_PATH" ]]; then
  # shellcheck disable=SC1090
  source "$INCUS_CONNECTION_INFO_PATH"
  if [[ "$REMOTE_DOCKER_HOST_EXPLICIT" -eq 0 && -n "${HOST_LISTEN_ADDRESS:-}" ]]; then
    REMOTE_DOCKER_HOST="$HOST_LISTEN_ADDRESS"
  fi
  if [[ "$REMOTE_DOCKER_PORT_EXPLICIT" -eq 0 && -n "${SSH_HOST_PORT:-}" ]]; then
    REMOTE_DOCKER_PORT="$SSH_HOST_PORT"
  fi
fi

step "Bootstrapping platform stack and running smoke checks"
BOOTSTRAP_STACK_CMD=(
  ./scripts/bootstrap-stack.sh
  --profile k3d \
  --namespace "$NAMESPACE" \
  --release-name "$RELEASE_NAME" \
  --kubeconfig "$KUBECONFIG_PATH" \
  --bootstrap-config "$BOOTSTRAP_CONFIG_PATH" \
  --incus-vm-name "$INCUS_VM_NAME" \
  --incus-connection-info "$INCUS_CONNECTION_INFO_PATH" \
  --remote-docker-key "$REMOTE_DOCKER_KEY_PATH"
)
if [[ -n "$REMOTE_DOCKER_HOST" ]]; then
  BOOTSTRAP_STACK_CMD+=(--remote-docker-host "$REMOTE_DOCKER_HOST")
fi
if [[ -n "$REMOTE_DOCKER_PORT" ]]; then
  BOOTSTRAP_STACK_CMD+=(--remote-docker-port "$REMOTE_DOCKER_PORT")
fi
if [[ "${BOOTSTRAP_VERBOSE:-0}" == "1" ]]; then
  BOOTSTRAP_STACK_CMD+=(--verbose)
fi
run_quiet "${BOOTSTRAP_STACK_CMD[@]}"
ok "Platform stack is bootstrapped"

run_quiet ./scripts/test-local-k3d.sh \
  --release-name "$RELEASE_NAME" \
  --namespace "$NAMESPACE" \
  --kubeconfig "$KUBECONFIG_PATH" \
  --skip-install
ok "Smoke checks passed"
echo
echo "Local bootstrap complete."
echo "Summary:"
echo "  Kubeconfig path: ${KUBECONFIG}"
echo "  Incus VM: ${INCUS_VM_NAME}"
echo "  Remote Docker endpoint: ssh://docker-remote@${REMOTE_DOCKER_HOST}:${REMOTE_DOCKER_PORT}"
echo "  Remote Docker SSH secret: openclaw-remote-docker-ssh"
echo "  OpenClaw gateway token: ${OPENCLAW_GATEWAY_TOKEN_VALUE}"
echo "  OpenClaw URL: http://${OPENCLAW_HOST_VALUE}"
echo "  Nextcloud URL: http://${NEXTCLOUD_HOST_VALUE}"
echo "  Nextcloud MCP URL: http://${NEXTCLOUD_MCP_HOST_VALUE}"
echo "  OpenClaw main model: ${OPENCLAW_MAIN_MODEL}"
echo "  OpenClaw architect model: ${OPENCLAW_ARCHITECT_MODEL}"
echo "  OpenClaw coder model: ${OPENCLAW_CODER_MODEL}"
echo "  Gitea URL: http://${GITEA_HOST_VALUE}"
echo "  Registry URL: https://${REGISTRY_HOST_VALUE}"
echo "  Vaultwarden URL: http://${VAULTWARDEN_HOST_VALUE}"
echo "  Paperless URL: http://${PAPERLESS_HOST_VALUE}"
echo "  Bootstrap log: ${BOOTSTRAP_LOG_FILE}"
