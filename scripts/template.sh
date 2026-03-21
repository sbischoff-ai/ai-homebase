#!/usr/bin/env bash
set -euo pipefail

RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
VALUES_FILES=()
KUBE_CONTEXT="${KUBE_CONTEXT:-}"
SET_ARGS=()

normalize_service_key() {
  case "$1" in
    cert-manager|certManager) echo "certManager" ;;
    openclaw|nextcloud|gitea|infisical) echo "$1" ;;
    paperless-ngx|paperlessNgx) echo "paperlessNgx" ;;
    *) return 1 ;;
  esac
}

usage() {
  cat <<USAGE
Usage: $0 [options]

Render platform-stack manifests with layered values and optional service toggles.

Options:
  --release-name <name>       Helm release name (default: ${RELEASE_NAME})
  --namespace <name>          Kubernetes namespace (default: ${NAMESPACE})
  --values-file <path>        Values file path (repeatable)
  --enable-service <name>     Enable a service (repeatable)
  --disable-service <name>    Disable a service (repeatable)
  --kube-context <context>    Optional kube context
  -h, --help                  Show this help message

Examples:
  $0 --values-file charts/platform-stack/values.yaml
  $0 --values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3d.yaml
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release-name) RELEASE_NAME="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --values-file) VALUES_FILES+=("$2"); shift 2 ;;
    --enable-service)
      service_key="$(normalize_service_key "$2")" || { echo "Unsupported service: $2" >&2; exit 1; }
      SET_ARGS+=(--set "${service_key}.enabled=true")
      shift 2
      ;;
    --disable-service)
      service_key="$(normalize_service_key "$2")" || { echo "Unsupported service: $2" >&2; exit 1; }
      SET_ARGS+=(--set "${service_key}.enabled=false")
      shift 2
      ;;
    --kube-context) KUBE_CONTEXT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ ${#VALUES_FILES[@]} -eq 0 ]]; then
  VALUES_FILES=("${VALUES_FILE:-charts/platform-stack/values.yaml}")
fi

KUBE_CONTEXT_ARGS=()
if [[ -n "$KUBE_CONTEXT" ]]; then
  KUBE_CONTEXT_ARGS=(--kube-context "$KUBE_CONTEXT")
fi

VALUES_ARGS=()
for values_file in "${VALUES_FILES[@]}"; do
  VALUES_ARGS+=(--values "$values_file")
done

helm template "$RELEASE_NAME" charts/platform-stack \
  "${KUBE_CONTEXT_ARGS[@]}" \
  --namespace "$NAMESPACE" \
  "${VALUES_ARGS[@]}" \
  "${SET_ARGS[@]}"
