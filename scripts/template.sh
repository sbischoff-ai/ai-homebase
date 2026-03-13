#!/usr/bin/env bash
set -euo pipefail

RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
VALUES_FILE="${VALUES_FILE:-charts/platform-stack/values-dev.yaml}"
KUBE_CONTEXT="${KUBE_CONTEXT:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release-name) RELEASE_NAME="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --values-file) VALUES_FILE="$2"; shift 2 ;;
    --kube-context) KUBE_CONTEXT="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

KUBE_CONTEXT_ARGS=()
if [[ -n "$KUBE_CONTEXT" ]]; then
  KUBE_CONTEXT_ARGS=(--kube-context "$KUBE_CONTEXT")
fi

helm template "$RELEASE_NAME" charts/platform-stack \
  "${KUBE_CONTEXT_ARGS[@]}" \
  --namespace "$NAMESPACE" \
  --values "$VALUES_FILE"
