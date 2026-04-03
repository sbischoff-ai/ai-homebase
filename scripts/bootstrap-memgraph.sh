#!/usr/bin/env bash
set -Eeuo pipefail

RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-}"
RAW_KUBECONFIG="${KUBECONFIG:-}"
KUBE_CONTEXT="${KUBE_CONTEXT:-}"
SEED_FILE="${SEED_FILE:-charts/platform-stack/files/memgraph-seed.cypher}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-300s}"

usage() {
  cat <<USAGE
Usage: $0 [options]

Apply the canonical Memgraph bootstrap seed to the live cluster.

Options:
  --release-name <name>    Helm release name (default: ${RELEASE_NAME})
  --namespace <name>       Kubernetes namespace (default: ${NAMESPACE})
  --kubeconfig <path>      Optional kubeconfig path
  --kube-context <ctx>     Optional kube context
  --seed-file <path>       Seed Cypher file (default: ${SEED_FILE})
  --rollout-timeout <dur>  Memgraph rollout wait timeout (default: ${ROLLOUT_TIMEOUT})
  -h, --help               Show this help message
USAGE
}

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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release-name) RELEASE_NAME="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --kube-context) KUBE_CONTEXT="$2"; shift 2 ;;
    --seed-file) SEED_FILE="$2"; shift 2 ;;
    --rollout-timeout) ROLLOUT_TIMEOUT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$KUBECONFIG_PATH" ]]; then
  KUBECONFIG_PATH="$(normalize_kubeconfig_path "$RAW_KUBECONFIG")"
fi

for cmd in kubectl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

if [[ ! -f "$SEED_FILE" ]]; then
  echo "Memgraph seed file not found: $SEED_FILE" >&2
  exit 1
fi

KUBECTL_ARGS=()
if [[ -n "$KUBECONFIG_PATH" ]]; then
  KUBECTL_ARGS+=(--kubeconfig "$KUBECONFIG_PATH")
fi
if [[ -n "$KUBE_CONTEXT" ]]; then
  KUBECTL_ARGS+=(--context "$KUBE_CONTEXT")
fi

DEPLOYMENT_NAME="${RELEASE_NAME}-memgraph"

kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" rollout status "deployment/${DEPLOYMENT_NAME}" --timeout "$ROLLOUT_TIMEOUT"
kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" exec -i "deployment/${DEPLOYMENT_NAME}" -- sh -ceu '
  cat >/tmp/memgraph-seed.cypher
  mgconsole --host 127.0.0.1 --port 7687 --output-format csv < /tmp/memgraph-seed.cypher
' < "$SEED_FILE"
