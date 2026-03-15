#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/lib/logging.sh"

RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
VALUES_FILES=()
KUBE_CONTEXT="${KUBE_CONTEXT:-}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${KUBECONFIG:-}}"

usage() {
  cat <<USAGE
Usage: $0 [options]

Deploy the k3d profile and run local smoke checks.

Options:
  --release-name <name>       Helm release name (default: ${RELEASE_NAME})
  --namespace <name>          Kubernetes namespace (default: ${NAMESPACE})
  --values-file <path>        Values file path (repeatable)
  --kube-context <context>    Optional kube context
  --kubeconfig <path>         Optional kubeconfig path (overrides KUBECONFIG env)
  --verbose                   Stream full command output
  -h, --help                  Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release-name) RELEASE_NAME="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --values-file) VALUES_FILES+=("$2"); shift 2 ;;
    --kube-context) KUBE_CONTEXT="$2"; shift 2 ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --verbose) BOOTSTRAP_VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

bootstrap_init_logging

if [[ ${#VALUES_FILES[@]} -eq 0 ]]; then
  VALUES_FILES=(
    "charts/platform-stack/values-dev.yaml"
    "charts/platform-stack/values-k3d.yaml"
  )
fi

for cmd in helm kubectl curl python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Missing required dependency: $cmd"
    exit 1
  fi
done

HELM_CONTEXT_ARGS=()
KUBECTL_CONTEXT_ARGS=()
if [[ -n "$KUBE_CONTEXT" ]]; then
  HELM_CONTEXT_ARGS=(--kube-context "$KUBE_CONTEXT")
  KUBECTL_CONTEXT_ARGS=(--context "$KUBE_CONTEXT")
fi

HELM_KUBECONFIG_ARGS=()
KUBECTL_KUBECONFIG_ARGS=()
if [[ -n "$KUBECONFIG_PATH" ]]; then
  HELM_KUBECONFIG_ARGS=(--kubeconfig "$KUBECONFIG_PATH")
  KUBECTL_KUBECONFIG_ARGS=(--kubeconfig "$KUBECONFIG_PATH")
fi

VALUES_ARGS=()
for values_file in "${VALUES_FILES[@]}"; do
  VALUES_ARGS+=(--values "$values_file")
done

dump_diagnostics() {
  echo
  echo "--- Diagnostics for namespace ${NAMESPACE} ---" >&2
  kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get pods -o wide >&2 || true
  kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get deployments >&2 || true

  mapfile -t failing_pods < <(kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get pods --no-headers 2>/dev/null | awk '$3 != "Running" && $3 != "Completed" {print $1}')
  if [[ ${#failing_pods[@]} -gt 0 ]]; then
    echo "\nDescribing non-running pods:" >&2
    for pod in "${failing_pods[@]}"; do
      echo "\n# kubectl describe pod/${pod}" >&2
      kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" describe "pod/${pod}" >&2 || true
    done
  fi
}

on_error() {
  local line="$1"
  fail "Local k3d smoke test failed near line ${line}."
  dump_diagnostics
  echo "Bootstrap log: ${BOOTSTRAP_LOG_FILE}" >&2
}
trap 'on_error ${LINENO}' ERR

resolve_deployment_name() {
  local app_name="$1"
  local deployment_name
  deployment_name="$(kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get deployment \
    -l "app.kubernetes.io/instance=${RELEASE_NAME},app.kubernetes.io/name=${app_name}" \
    -o jsonpath='{.items[0].metadata.name}')"

  if [[ -z "$deployment_name" ]]; then
    fail "Unable to find deployment for app=${app_name}, release=${RELEASE_NAME} in namespace=${NAMESPACE}"
    return 1
  fi

  echo "$deployment_name"
}

wait_for_workload() {
  local app_name="$1"
  local deployment_name
  deployment_name="$(resolve_deployment_name "$app_name")"

  step "Waiting for deployment/${deployment_name} rollout"
  run_quiet kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" rollout status "deployment/${deployment_name}" --timeout=300s

  step "Waiting for pods to become Ready (app=${app_name})"
  run_quiet kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" wait \
    --for=condition=Ready \
    pod \
    -l "app.kubernetes.io/instance=${RELEASE_NAME},app.kubernetes.io/name=${app_name}" \
    --timeout=300s
}

is_openclaw_ingress_enabled() {
  helm get values "$RELEASE_NAME" \
    "${HELM_KUBECONFIG_ARGS[@]}" \
    "${HELM_CONTEXT_ARGS[@]}" \
    --namespace "$NAMESPACE" \
    --all \
    --output json | python3 -c '
import json
import sys

values = json.load(sys.stdin)
enabled = values.get("openclaw", {}).get("ingress", {}).get("enabled", False)
print("true" if enabled else "false")
'
}

step "Updating Helm dependencies"
run_quiet helm dependency update charts/platform-stack

step "Installing/upgrading release ${RELEASE_NAME}"
run_quiet helm upgrade --install "$RELEASE_NAME" charts/platform-stack \
  "${HELM_KUBECONFIG_ARGS[@]}" \
  "${HELM_CONTEXT_ARGS[@]}" \
  --namespace "$NAMESPACE" \
  --create-namespace \
  "${VALUES_ARGS[@]}"

wait_for_workload openclaw
wait_for_workload openhands

if [[ "$(is_openclaw_ingress_enabled)" == "true" ]]; then
  step "Checking openclaw ingress endpoint"
  run_quiet curl --silent --show-error --fail \
    -H 'Host: openclaw.localtest.me' \
    http://127.0.0.1/
else
  warn "Skipping OpenClaw ingress endpoint check because openclaw.ingress.enabled=false in effective values"
fi

step "Checking openhands ingress endpoint"
run_quiet curl --silent --show-error --fail \
  -H 'Host: openhands.localtest.me' \
  http://127.0.0.1/

echo "Local k3d smoke checks passed for release=${RELEASE_NAME} namespace=${NAMESPACE}"
echo "Bootstrap log: ${BOOTSTRAP_LOG_FILE}"
