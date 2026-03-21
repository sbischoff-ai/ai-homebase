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
    "charts/platform-stack/values.yaml"
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


CURRENT_COMMAND=""

run_checked() {
  CURRENT_COMMAND="$(printf '%q ' "$@")"
  run_quiet "$@"
}

dump_diagnostics() {
  echo
  echo "--- Diagnostics for namespace ${NAMESPACE} ---" >&2
  kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get pods -o wide >&2 || true
  kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get deployments >&2 || true

  mapfile -t failing_pods < <(kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get pods --no-headers 2>/dev/null | awk '$3 != "Running" && $3 != "Completed" {print $1}')
  if [[ ${#failing_pods[@]} -gt 0 && "${BOOTSTRAP_VERBOSE:-0}" == "1" ]]; then
    echo >&2
    echo "Describing non-running pods:" >&2
    for pod in "${failing_pods[@]}"; do
      echo >&2
      echo "# kubectl describe pod/${pod}" >&2
      kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" describe "pod/${pod}" >&2 || true
    done
  elif [[ ${#failing_pods[@]} -gt 0 ]]; then
    echo >&2
    echo "Non-running pods detected: ${failing_pods[*]}" >&2
    echo "Run with --verbose to include full 'kubectl describe pod/<name>' diagnostics." >&2
  fi
}

print_top_level_status_summary() {
  echo "--- Top-level Kubernetes status (${NAMESPACE}) ---" >&2
  kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get pods >&2 || true
  kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get deploy,statefulset,job,ingress >&2 || true
}

print_log_excerpt() {
  echo "--- Stderr/log excerpt (last 25 lines) ---" >&2
  if [[ -f "$BOOTSTRAP_LOG_FILE" ]]; then
    tail -n 25 "$BOOTSTRAP_LOG_FILE" >&2 || true
  else
    echo "Bootstrap log file not found: ${BOOTSTRAP_LOG_FILE}" >&2
  fi
}

first_matching_log_line() {
  local pattern="$1"
  if [[ ! -f "$BOOTSTRAP_LOG_FILE" ]]; then
    return 0
  fi
  awk -v pat="$pattern" '$0 ~ pat {print; exit}' "$BOOTSTRAP_LOG_FILE"
}

print_helm_failure_summary() {
  local actionable_error
  actionable_error="$(first_matching_log_line '^Error:|UPGRADE FAILED|INSTALLATION FAILED|found in Chart[.]yaml, but missing in charts/')"
  if [[ -n "$actionable_error" ]]; then
    echo "--- Helm actionable error ---" >&2
    echo "$actionable_error" >&2
  fi

  local object_identifier=""
  local object_pattern='resource mapping not found for name: "([^"]+)"'
  local chart_pattern='chart "([^"]+)"'
  if [[ "$actionable_error" =~ $object_pattern ]]; then
    object_identifier="${BASH_REMATCH[1]}"
  elif [[ "$actionable_error" =~ $chart_pattern ]]; then
    object_identifier="${BASH_REMATCH[1]}"
  elif [[ "$actionable_error" == *"found in Chart.yaml, but missing in charts/"* ]]; then
    object_identifier="platform-stack dependencies"
  fi

  if [[ -n "$object_identifier" ]]; then
    echo "Helm context object/chart: ${object_identifier}" >&2
  fi
}

print_failure_hints() {
  local hints=()
  local log_content=""

  if [[ -f "$BOOTSTRAP_LOG_FILE" ]]; then
    log_content="$(tail -n 200 "$BOOTSTRAP_LOG_FILE" 2>/dev/null || true)"
  fi

  if [[ "$log_content" == *"ingress class annotation"* ]] || [[ "$log_content" == *"can not be set when the class field is also set"* ]]; then
    hints+=("Ingress class conflict detected: set either ingressClassName or kubernetes.io/ingress.class annotation, but not both.")
  fi

  if [[ "$log_content" == *"found in Chart.yaml, but missing in charts/"* ]]; then
    hints+=("Missing chart dependencies: run 'helm dependency update charts/platform-stack' before retrying.")
  fi

  if [[ "$log_content" == *"timed out waiting for the condition"* ]] || [[ "$log_content" == *"no matching resources found"* ]]; then
    hints+=("Possible Kubernetes API readiness race: wait for cluster/system pods to become Ready, then retry deployment and rollout checks.")
  fi

  if [[ ${#hints[@]} -gt 0 ]]; then
    echo "--- Common failure hints ---" >&2
    for hint in "${hints[@]}"; do
      echo "- ${hint}" >&2
    done
  fi
}

print_next_steps() {
  echo "--- What to do next ---" >&2
  echo "1) Re-run with verbose diagnostics:" >&2
  echo "   ./scripts/test-local-k3d.sh --release-name ${RELEASE_NAME} --namespace ${NAMESPACE} --verbose" >&2
  echo "2) Inspect namespace resources and events:" >&2
  echo "   kubectl ${KUBECTL_KUBECONFIG_ARGS[*]} ${KUBECTL_CONTEXT_ARGS[*]} -n ${NAMESPACE} get pods,deploy,statefulset,job,ingress" >&2
  echo "   kubectl ${KUBECTL_KUBECONFIG_ARGS[*]} ${KUBECTL_CONTEXT_ARGS[*]} -n ${NAMESPACE} get events --sort-by=.lastTimestamp | tail -n 40" >&2
  echo "3) If Helm failed, refresh dependencies and retry install:" >&2
  echo "   helm dependency update charts/platform-stack" >&2
  echo "   helm upgrade --install ${RELEASE_NAME} charts/platform-stack --namespace ${NAMESPACE} --create-namespace ${VALUES_ARGS[*]}" >&2
  echo "4) Review full bootstrap log:" >&2
  echo "   less ${BOOTSTRAP_LOG_FILE}" >&2
}

on_error() {
  local line="$1"
  local failed_command="${CURRENT_COMMAND:-${2:-unknown}}"
  fail "Local k3d smoke test failed near line ${line}."
  echo "Failed command: ${failed_command}" >&2

  if [[ "$failed_command" == *"helm "* ]] || [[ "$failed_command" == helm* ]]; then
    print_helm_failure_summary
  fi

  print_log_excerpt
  print_top_level_status_summary
  print_failure_hints
  dump_diagnostics
  print_next_steps
  echo "Bootstrap log: ${BOOTSTRAP_LOG_FILE}" >&2
}
trap 'on_error ${LINENO} "${BASH_COMMAND}"' ERR

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
  run_checked kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" rollout status "deployment/${deployment_name}" --timeout=600s

  step "Waiting for pods to become Ready (app=${app_name})"
  run_checked kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" wait \
    --for=condition=Ready \
    pod \
    -l "app.kubernetes.io/instance=${RELEASE_NAME},app.kubernetes.io/name=${app_name}" \
    --timeout=600s
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
run_checked helm dependency update charts/platform-stack

step "Installing/upgrading release ${RELEASE_NAME}"
run_checked helm upgrade --install "$RELEASE_NAME" charts/platform-stack \
  "${HELM_KUBECONFIG_ARGS[@]}" \
  "${HELM_CONTEXT_ARGS[@]}" \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --hide-notes \
  "${VALUES_ARGS[@]}"

wait_for_workload openclaw

if [[ "$(is_openclaw_ingress_enabled)" == "true" ]]; then
  step "Checking openclaw ingress endpoint"
  run_checked curl --silent --show-error --fail \
    -H 'Host: openclaw.localtest.me' \
    http://127.0.0.1/
else
  warn "Skipping OpenClaw ingress endpoint check because openclaw.ingress.enabled=false in effective values"
fi


echo "Local k3d smoke checks passed for release=${RELEASE_NAME} namespace=${NAMESPACE}"
echo "Bootstrap log: ${BOOTSTRAP_LOG_FILE}"
