#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/lib/logging.sh"

CLUSTER_NAME="${CLUSTER_NAME:-ai-homebase-dev}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${HOME}/.kube/k3d-${CLUSTER_NAME}.yaml}"
WG_HOST="${WG_HOST:-wg.localtest.me}"
INCUS_VM_NAME="${INCUS_VM_NAME:-openclaw-sandbox}"
WG_PASSWORD_OUTPUT=""

usage() {
  cat <<USAGE
Usage: $0 [options]

End-to-end local bootstrap for k3d: cluster + ingress-nginx + secrets + deploy + smoke checks.

Options:
  --cluster-name <name>    k3d cluster name (default: ${CLUSTER_NAME})
  --namespace <name>       Kubernetes namespace (default: ${NAMESPACE})
  --release-name <name>    Helm release name (default: ${RELEASE_NAME})
  --kubeconfig <path>      Dedicated kubeconfig path (default: ${KUBECONFIG_PATH})
  --wg-host <host>         WireGuard host clients and the local wg-easy Ingress should use (default: ${WG_HOST})
  --incus-vm-name <name>   Incus VM name for the remote Docker sandbox (default: ${INCUS_VM_NAME})
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
    --wg-host) WG_HOST="$2"; shift 2 ;;
    --incus-vm-name) INCUS_VM_NAME="$2"; shift 2 ;;
    --verbose) BOOTSTRAP_VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

bootstrap_init_logging
export KUBECONFIG="$KUBECONFIG_PATH"
WG_PASSWORD_OUTPUT="$(mktemp /tmp/ai-homebase-wg-password.XXXXXX)"

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

step "Bootstrapping local secrets"
run_quiet ./scripts/k3d-bootstrap-secrets.sh \
  --namespace "$NAMESPACE" \
  --release-name "$RELEASE_NAME" \
  --kubeconfig "$KUBECONFIG_PATH" \
  --wg-host "$WG_HOST" \
  --wg-password-out "$WG_PASSWORD_OUTPUT"
ok "Secrets are ready"

step "Deploying platform stack and running smoke checks"
run_quiet ./scripts/test-local-k3d.sh \
  --release-name "$RELEASE_NAME" \
  --namespace "$NAMESPACE" \
  --kubeconfig "$KUBECONFIG_PATH" \
  --values-file charts/platform-stack/values.yaml \
  --values-file charts/platform-stack/values-k3d.yaml
ok "Smoke checks passed"

WG_PASSWORD="(not available)"
if [[ -s "$WG_PASSWORD_OUTPUT" ]]; then
  WG_PASSWORD="$(cat "$WG_PASSWORD_OUTPUT")"
fi
rm -f "$WG_PASSWORD_OUTPUT"

echo
echo "Local bootstrap complete."
echo "Summary:"
echo "  Kubeconfig: ${KUBECONFIG}"
echo "  Incus VM: ${INCUS_VM_NAME}"
echo "  Remote Docker endpoint: ssh://docker-remote@host.k3d.internal:2222"
echo "  wg-easy URL (via ingress-nginx): http://${WG_HOST}"
echo "  OpenHands URL: http://openhands.localtest.me"
echo "  Infisical URL: http://infisical.localtest.me"
echo "  wg-easy UI password: ${WG_PASSWORD}"
echo "  Bootstrap log: ${BOOTSTRAP_LOG_FILE}"
