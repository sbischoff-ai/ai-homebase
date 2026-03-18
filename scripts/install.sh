#!/usr/bin/env bash
set -euo pipefail

RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
PROFILE="${PROFILE:-}"
VALUES_FILES=()
KUBE_CONTEXT="${KUBE_CONTEXT:-}"
SET_ARGS=()

normalize_service_key() {
  case "$1" in
    openclaw|openhands|nextcloud|gitea|infisical) echo "$1" ;;
    paperless-ngx|paperlessNgx) echo "paperlessNgx" ;;
    wg-easy|wgEasy) echo "wgEasy" ;;
    *) return 1 ;;
  esac
}

default_values_files_for_profile() {
  case "$1" in
    k3d)
      printf '%s\n' "charts/platform-stack/values.yaml" "charts/platform-stack/values-k3d.yaml"
      ;;
    k3s)
      printf '%s\n' "charts/platform-stack/values.yaml" "charts/platform-stack/values-k3s.yaml"
      ;;
    *) return 1 ;;
  esac
}

usage() {
  cat <<USAGE
Usage: $0 --profile <k3d|k3s> [options]

Install or upgrade a supported target profile with layered values and optional service toggles.

Options:
  --profile <k3d|k3s>         Deployment profile (required)
  --release-name <name>       Helm release name (default: ${RELEASE_NAME})
  --namespace <name>          Kubernetes namespace (default: ${NAMESPACE})
  --values-file <path>        Values file path (repeatable)
  --enable-service <name>     Enable a service (repeatable)
  --disable-service <name>    Disable a service (repeatable)
  --kube-context <context>    Optional kube context
  -h, --help                  Show this help message

Supported services: openclaw, openhands, nextcloud, gitea, paperless-ngx, infisical, wg-easy
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
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

if [[ -z "$PROFILE" ]]; then
  echo "Missing required argument: --profile <k3d|k3s>" >&2
  usage
  exit 1
fi

if [[ ${#VALUES_FILES[@]} -eq 0 ]]; then
  mapfile -t VALUES_FILES < <(default_values_files_for_profile "$PROFILE") || {
    echo "Unsupported profile: $PROFILE (supported: k3d, k3s)" >&2
    exit 1
  }
fi

KUBE_CONTEXT_ARGS=()
if [[ -n "$KUBE_CONTEXT" ]]; then
  KUBE_CONTEXT_ARGS=(--kube-context "$KUBE_CONTEXT")
fi

VALUES_ARGS=()
for values_file in "${VALUES_FILES[@]}"; do
  VALUES_ARGS+=(--values "$values_file")
done

helm dependency update charts/platform-stack
helm upgrade --install "$RELEASE_NAME" charts/platform-stack \
  "${KUBE_CONTEXT_ARGS[@]}" \
  --namespace "$NAMESPACE" \
  --create-namespace \
  "${VALUES_ARGS[@]}" \
  "${SET_ARGS[@]}"
