#!/usr/bin/env bash
set -Eeuo pipefail

RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
VALUES_FILES=()
KUBE_CONTEXT="${KUBE_CONTEXT:-}"

usage() {
  cat <<USAGE
Usage: $0 [options]

Deploy the k3d profile and run local smoke checks.

Options:
  --release-name <name>       Helm release name (default: ${RELEASE_NAME})
  --namespace <name>          Kubernetes namespace (default: ${NAMESPACE})
  --values-file <path>        Values file path (repeatable)
  --kube-context <context>    Optional kube context
  -h, --help                  Show this help message
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
  VALUES_FILES=(
    "charts/platform-stack/values-dev.yaml"
    "charts/platform-stack/values-k3d.yaml"
  )
fi

for cmd in helm kubectl curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required dependency: $cmd" >&2
    exit 1
  fi
done

HELM_CONTEXT_ARGS=()
KUBECTL_CONTEXT_ARGS=()
if [[ -n "$KUBE_CONTEXT" ]]; then
  HELM_CONTEXT_ARGS=(--kube-context "$KUBE_CONTEXT")
  KUBECTL_CONTEXT_ARGS=(--context "$KUBE_CONTEXT")
fi

VALUES_ARGS=()
for values_file in "${VALUES_FILES[@]}"; do
  VALUES_ARGS+=(--values "$values_file")
done

dump_diagnostics() {
  echo
  echo "--- Diagnostics for namespace ${NAMESPACE} ---" >&2
  kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get pods -o wide >&2 || true
  kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get deployments >&2 || true

  mapfile -t failing_pods < <(kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get pods --no-headers 2>/dev/null | awk '$3 != "Running" && $3 != "Completed" {print $1}')
  if [[ ${#failing_pods[@]} -gt 0 ]]; then
    echo "\nDescribing non-running pods:" >&2
    for pod in "${failing_pods[@]}"; do
      echo "\n# kubectl describe pod/${pod}" >&2
      kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" describe "pod/${pod}" >&2 || true
    done
  fi
}

on_error() {
  local line="$1"
  echo "Error: local k3d smoke test failed near line ${line}." >&2
  dump_diagnostics
}
trap 'on_error ${LINENO}' ERR

resolve_deployment_name() {
  local app_name="$1"
  local deployment_name
  deployment_name="$(kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get deployment \
    -l "app.kubernetes.io/instance=${RELEASE_NAME},app.kubernetes.io/name=${app_name}" \
    -o jsonpath='{.items[0].metadata.name}')"

  if [[ -z "$deployment_name" ]]; then
    echo "Unable to find deployment for app=${app_name}, release=${RELEASE_NAME} in namespace=${NAMESPACE}" >&2
    return 1
  fi

  echo "$deployment_name"
}

wait_for_workload() {
  local app_name="$1"
  local deployment_name
  deployment_name="$(resolve_deployment_name "$app_name")"

  echo "Waiting for deployment/${deployment_name} rollout"
  kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" rollout status "deployment/${deployment_name}" --timeout=300s

  echo "Waiting for pods to become Ready (app=${app_name})"
  kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" wait \
    --for=condition=Ready \
    pod \
    -l "app.kubernetes.io/instance=${RELEASE_NAME},app.kubernetes.io/name=${app_name}" \
    --timeout=300s
}

wait_for_local_port() {
  local port="$1"
  for _ in {1..30}; do
    if curl --silent --show-error --fail "http://127.0.0.1:${port}/" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

echo "Updating Helm dependencies"
helm dependency update charts/platform-stack

echo "Installing/upgrading release ${RELEASE_NAME}"
helm upgrade --install "$RELEASE_NAME" charts/platform-stack \
  "${HELM_CONTEXT_ARGS[@]}" \
  --namespace "$NAMESPACE" \
  --create-namespace \
  "${VALUES_ARGS[@]}"

wait_for_workload openclaw
wait_for_workload openhands

echo "Checking openclaw ingress endpoint"
curl --silent --show-error --fail \
  -H 'Host: openclaw.localtest.me' \
  http://127.0.0.1/ >/dev/null

echo "Checking openhands service endpoint through port-forward"
OPENHANDS_POD="$(kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get pods \
  -l "app.kubernetes.io/instance=${RELEASE_NAME},app.kubernetes.io/name=openhands" \
  -o jsonpath='{.items[0].metadata.name}')"

if [[ -z "$OPENHANDS_POD" ]]; then
  echo "Unable to find an openhands pod for port-forward check" >&2
  exit 1
fi

kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" port-forward "pod/${OPENHANDS_POD}" 18080:80 >/tmp/openhands-port-forward.log 2>&1 &
PORT_FORWARD_PID=$!
cleanup() {
  if [[ -n "${PORT_FORWARD_PID:-}" ]]; then
    kill "$PORT_FORWARD_PID" >/dev/null 2>&1 || true
    wait "$PORT_FORWARD_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

wait_for_local_port 18080
curl --silent --show-error --fail http://127.0.0.1:18080/ >/dev/null

echo "Local k3d smoke checks passed for release=${RELEASE_NAME} namespace=${NAMESPACE}"
