#!/usr/bin/env bash
set -euo pipefail

RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
VALUES_FILES=()
KUBE_CONTEXT="${KUBE_CONTEXT:-}"

usage() {
  cat <<USAGE
Usage: $0 [options]

Lint all platform charts and the umbrella chart.

Options:
  --release-name <name>      Helm release name (default: ${RELEASE_NAME})
  --namespace <name>         Kubernetes namespace (default: ${NAMESPACE})
  --values-file <path>       Values file for platform-stack (repeatable)
  --kube-context <context>   Optional kube context
  -h, --help                 Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release-name) RELEASE_NAME="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --values-file) VALUES_FILES+=("$2"); shift 2 ;;
    --kube-context) KUBE_CONTEXT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ ${#VALUES_FILES[@]} -eq 0 ]]; then
  VALUES_FILES=("${VALUES_FILE:-charts/platform-stack/values-dev.yaml}")
fi

KUBE_CONTEXT_ARGS=()
if [[ -n "$KUBE_CONTEXT" ]]; then
  KUBE_CONTEXT_ARGS=(--kube-context "$KUBE_CONTEXT")
fi

VALUES_ARGS=()
for values_file in "${VALUES_FILES[@]}"; do
  VALUES_ARGS+=(--values "$values_file")
done

CHARTS=(
  charts/openclaw
  charts/openhands
  charts/nextcloud
  charts/gitea
  charts/paperless-ngx
  charts/infisical
  charts/wg-easy
)

echo "Linting component charts"
for chart in "${CHARTS[@]}"; do
  echo "- helm lint ${chart}"
  helm lint "$chart"
done

echo "Linting umbrella chart for release=$RELEASE_NAME namespace=$NAMESPACE values=${VALUES_FILES[*]}"
helm lint charts/platform-stack "${KUBE_CONTEXT_ARGS[@]}" \
  --namespace "$NAMESPACE" \
  "${VALUES_ARGS[@]}"
