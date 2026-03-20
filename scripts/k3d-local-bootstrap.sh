#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/lib/logging.sh"

CLUSTER_NAME="${CLUSTER_NAME:-ai-homebase-dev}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${HOME}/.kube/k3d-${CLUSTER_NAME}.yaml}"
INCUS_VM_NAME="${INCUS_VM_NAME:-openclaw-sandbox}"
REMOTE_DOCKER_HOST="${REMOTE_DOCKER_HOST:-host.k3d.internal}"
REMOTE_DOCKER_PORT="${REMOTE_DOCKER_PORT:-2222}"
REMOTE_DOCKER_KEY_PATH="${REMOTE_DOCKER_KEY_PATH:-${HOME}/.local/state/ai-homebase/incus/${INCUS_VM_NAME}-id_ed25519}"
INCUS_CONNECTION_INFO_PATH="${INCUS_CONNECTION_INFO_PATH:-}"
OVERRIDE_VALUES_FILE=""
REMOTE_DOCKER_HOST_EXPLICIT=0
REMOTE_DOCKER_PORT_EXPLICIT=0

usage() {
  cat <<USAGE
Usage: $0 [options]

End-to-end local bootstrap for k3d: cluster + ingress-nginx + secrets + deploy + smoke checks.

Options:
  --cluster-name <name>    k3d cluster name (default: ${CLUSTER_NAME})
  --namespace <name>       Kubernetes namespace (default: ${NAMESPACE})
  --release-name <name>    Helm release name (default: ${RELEASE_NAME})
  --kubeconfig <path>      Dedicated kubeconfig path (default: ${KUBECONFIG_PATH})
  --incus-vm-name <name>   Incus VM name for the remote Docker sandbox (default: ${INCUS_VM_NAME})
  --remote-docker-host <h> Hostname OpenClaw should use for the remote Docker SSH endpoint (default: ${REMOTE_DOCKER_HOST})
  --remote-docker-port <p> SSH port for the remote Docker endpoint (default: ${REMOTE_DOCKER_PORT})
  --remote-docker-key <p>  Private key path for the OpenClaw remote Docker Secret (default: ${REMOTE_DOCKER_KEY_PATH})
  --incus-connection-info <p> Path to the Incus VM connection info env file (default: ${INCUS_CONNECTION_INFO_PATH})
  OPENAI_API_KEY env var   Required OpenAI API key for bootstrap secret generation
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
    --incus-vm-name) INCUS_VM_NAME="$2"; shift 2 ;;
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

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  fail "OPENAI_API_KEY is required. Export it before running this script (for example: export OPENAI_API_KEY=\"sk-...\")."
  exit 1
fi

step "Bootstrapping k3d cluster and ingress"
K3D_UP_CMD=(
  ./scripts/k3d-up.sh
  --cluster-name "$CLUSTER_NAME"
  --kubeconfig "$KUBECONFIG_PATH"
)


run_quiet "${K3D_UP_CMD[@]}"
ok "Cluster is ready"

step "Bootstrapping Incus sandbox VM"
run_quiet ./scripts/incus-vm-up.sh --vm-name "$INCUS_VM_NAME"
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

step "Bootstrapping local secrets"
run_quiet ./scripts/k3d-bootstrap-secrets.sh \
  --namespace "$NAMESPACE" \
  --release-name "$RELEASE_NAME" \
  --kubeconfig "$KUBECONFIG_PATH" \
  --remote-docker-host "$REMOTE_DOCKER_HOST" \
  --remote-docker-port "$REMOTE_DOCKER_PORT" \
  --remote-docker-key "$REMOTE_DOCKER_KEY_PATH"
ok "Secrets are ready"

OVERRIDE_VALUES_FILE="$(mktemp /tmp/ai-homebase-k3d-remote-docker.XXXXXX.yaml)"
cat >"$OVERRIDE_VALUES_FILE" <<EOF
openclaw:
  remoteDocker:
    dockerHost: ssh://docker-remote@${REMOTE_DOCKER_HOST}:${REMOTE_DOCKER_PORT}
EOF
trap 'rm -f "$OVERRIDE_VALUES_FILE"' EXIT

step "Deploying platform stack and running smoke checks"
run_quiet ./scripts/test-local-k3d.sh \
  --release-name "$RELEASE_NAME" \
  --namespace "$NAMESPACE" \
  --kubeconfig "$KUBECONFIG_PATH" \
  --values-file charts/platform-stack/values.yaml \
  --values-file charts/platform-stack/values-k3d.yaml \
  --values-file "$OVERRIDE_VALUES_FILE"
ok "Smoke checks passed"

rm -f "$OVERRIDE_VALUES_FILE"

echo
echo "Local bootstrap complete."
echo "Summary:"
echo "  Kubeconfig: ${KUBECONFIG}"
echo "  Incus VM: ${INCUS_VM_NAME}"
echo "  Remote Docker endpoint: ssh://docker-remote@${REMOTE_DOCKER_HOST}:${REMOTE_DOCKER_PORT}"
echo "  Remote Docker SSH secret: openclaw-remote-docker-ssh"
echo "  OpenClaw URL: http://openclaw.localtest.me"
echo "  OpenHands URL: http://openhands.localtest.me"
echo "  Infisical URL: http://infisical.localtest.me"
echo "  Bootstrap log: ${BOOTSTRAP_LOG_FILE}"
