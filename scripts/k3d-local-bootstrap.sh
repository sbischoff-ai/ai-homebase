#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-ai-homebase-dev}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${HOME}/.kube/k3d-${CLUSTER_NAME}.yaml}"
WG_HOST="${WG_HOST:-wg.localtest.me}"

usage() {
  cat <<USAGE
Usage: $0 [options]

End-to-end local bootstrap for k3d: cluster + ingress + secrets + deploy + smoke checks.

Options:
  --cluster-name <name>    k3d cluster name (default: ${CLUSTER_NAME})
  --namespace <name>       Kubernetes namespace (default: ${NAMESPACE})
  --release-name <name>    Helm release name (default: ${RELEASE_NAME})
  --kubeconfig <path>      Dedicated kubeconfig path (default: ${KUBECONFIG_PATH})
  --wg-host <host>         WireGuard host clients should use (default: ${WG_HOST})
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
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

./scripts/k3d-up.sh \
  --cluster-name "$CLUSTER_NAME" \
  --kubeconfig "$KUBECONFIG_PATH"

./scripts/k3d-bootstrap-secrets.sh \
  --namespace "$NAMESPACE" \
  --release-name "$RELEASE_NAME" \
  --kubeconfig "$KUBECONFIG_PATH" \
  --wg-host "$WG_HOST"

./scripts/test-local-k3d.sh \
  --release-name "$RELEASE_NAME" \
  --namespace "$NAMESPACE" \
  --kubeconfig "$KUBECONFIG_PATH" \
  --values-file charts/platform-stack/values-dev.yaml \
  --values-file charts/platform-stack/values-k3d.yaml

echo
echo "Local bootstrap complete."
echo "Use kubeconfig: ${KUBECONFIG_PATH}"
echo "Suggested next checks:"
echo "  kubectl --kubeconfig ${KUBECONFIG_PATH} -n ${NAMESPACE} get pods"
echo "  open http://${WG_HOST} (wg-easy UI)"
echo "  open http://openhands.localtest.me (OpenHands UI)"
echo "  open http://infisical.localtest.me (Infisical UI; first-login flow)"
