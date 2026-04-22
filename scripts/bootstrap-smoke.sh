#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/lib/logging.sh"

PROFILE="${PROFILE:-}"
RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
CLUSTER_NAME="${CLUSTER_NAME:-ai-homebase-dev}"
VALUES_FILES=()
KUBE_CONTEXT="${KUBE_CONTEXT:-}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-}"
RAW_KUBECONFIG="${KUBECONFIG:-}"
BOOTSTRAP_CONFIG_PATH="${BOOTSTRAP_CONFIG_PATH:-bootstrap.local.toml}"
REMOTE_DOCKER_SECRET_NAME="${REMOTE_DOCKER_SECRET_NAME:-}"
REMOTE_DOCKER_HOST="${REMOTE_DOCKER_HOST:-}"
REMOTE_DOCKER_PORT="${REMOTE_DOCKER_PORT:-}"
REMOTE_DOCKER_KEY_PATH="${REMOTE_DOCKER_KEY_PATH:-}"
INCUS_VM_NAME="${INCUS_VM_NAME:-openclaw-sandbox}"
INCUS_CONNECTION_INFO_PATH="${INCUS_CONNECTION_INFO_PATH:-${HOME}/.local/state/ai-homebase/incus/${INCUS_VM_NAME}.env}"
GITEA_ACTIONS_ENABLED="${GITEA_ACTIONS_ENABLED:-false}"
GITEA_ACTIONS_RUNNER_VM_NAME="${GITEA_ACTIONS_RUNNER_VM_NAME:-gitea-actions-runner}"
GITEA_ACTIONS_RUNNER_CONNECTION_INFO_PATH="${GITEA_ACTIONS_RUNNER_CONNECTION_INFO_PATH:-${HOME}/.local/state/ai-homebase/incus/${GITEA_ACTIONS_RUNNER_VM_NAME}.env}"
GITEA_ACTIONS_RUNNER_KEY_PATH="${GITEA_ACTIONS_RUNNER_KEY_PATH:-${HOME}/.local/state/ai-homebase/incus/${GITEA_ACTIONS_RUNNER_VM_NAME}-id_ed25519}"
EXPECTED_DEFAULT_SANDBOX_IMAGE="${EXPECTED_DEFAULT_SANDBOX_IMAGE:-}"
EXPECTED_CODER_SANDBOX_IMAGE="${EXPECTED_CODER_SANDBOX_IMAGE:-}"
OPENCLAW_WAIT_TIMEOUT="${OPENCLAW_WAIT_TIMEOUT:-600s}"
NEXTCLOUD_WAIT_TIMEOUT="${NEXTCLOUD_WAIT_TIMEOUT:-1200s}"
NEXTCLOUD_MCP_WAIT_TIMEOUT="${NEXTCLOUD_MCP_WAIT_TIMEOUT:-900s}"
GITEA_WAIT_TIMEOUT="${GITEA_WAIT_TIMEOUT:-1200s}"
VAULTWARDEN_WAIT_TIMEOUT="${VAULTWARDEN_WAIT_TIMEOUT:-900s}"
POSTFIX_RELAY_WAIT_TIMEOUT="${POSTFIX_RELAY_WAIT_TIMEOUT:-600s}"
PAPERLESS_WAIT_TIMEOUT="${PAPERLESS_WAIT_TIMEOUT:-1200s}"
QDRANT_WAIT_TIMEOUT="${QDRANT_WAIT_TIMEOUT:-900s}"
QDRANT_MCP_WAIT_TIMEOUT="${QDRANT_MCP_WAIT_TIMEOUT:-1200s}"
MEMGRAPH_WAIT_TIMEOUT="${MEMGRAPH_WAIT_TIMEOUT:-900s}"
MEMGRAPH_LAB_WAIT_TIMEOUT="${MEMGRAPH_LAB_WAIT_TIMEOUT:-900s}"
INGRESS_ENDPOINT_RETRIES="${INGRESS_ENDPOINT_RETRIES:-60}"
INGRESS_ENDPOINT_RETRY_DELAY_SECONDS="${INGRESS_ENDPOINT_RETRY_DELAY_SECONDS:-2}"

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

usage() {
  cat <<USAGE
Usage: $0 --profile <k3d|k3s> [options]

Run shared post-bootstrap smoke checks for a prepared ai-homebase cluster.

Options:
  --profile <k3d|k3s>       Supported target profile
  --cluster-name <name>      k3d cluster name used for the default kubeconfig path (default: ${CLUSTER_NAME})
  --release-name <name>       Helm release name (default: ${RELEASE_NAME})
  --namespace <name>          Kubernetes namespace (default: ${NAMESPACE})
  --bootstrap-config <path>   Bootstrap config file (default: ${BOOTSTRAP_CONFIG_PATH})
  --values-file <path>        Values file path (repeatable)
  --kube-context <context>    Optional kube context
  --kubeconfig <path>         Optional kubeconfig path (overrides KUBECONFIG env)
  --remote-docker-secret <n>  Override SSH secret name for OpenClaw remote Docker bootstrap
  --remote-docker-host <host> Override OpenClaw remote Docker SSH host during bootstrap
  --remote-docker-port <port> Override OpenClaw remote Docker SSH port during bootstrap
  --remote-docker-key <path>  Override OpenClaw remote Docker SSH private key during bootstrap
  --incus-vm-name <name>      Incus VM name for sandbox-side checks (default: ${INCUS_VM_NAME})
  --incus-connection-info <p> Incus VM env file for sandbox-side checks (default: ${INCUS_CONNECTION_INFO_PATH})
  Env timeouts                OPENCLAW_WAIT_TIMEOUT=${OPENCLAW_WAIT_TIMEOUT}, NEXTCLOUD_WAIT_TIMEOUT=${NEXTCLOUD_WAIT_TIMEOUT}, GITEA_WAIT_TIMEOUT=${GITEA_WAIT_TIMEOUT}, VAULTWARDEN_WAIT_TIMEOUT=${VAULTWARDEN_WAIT_TIMEOUT}, POSTFIX_RELAY_WAIT_TIMEOUT=${POSTFIX_RELAY_WAIT_TIMEOUT}, PAPERLESS_WAIT_TIMEOUT=${PAPERLESS_WAIT_TIMEOUT}
  Ingress retry tuning        INGRESS_ENDPOINT_RETRIES=${INGRESS_ENDPOINT_RETRIES}, INGRESS_ENDPOINT_RETRY_DELAY_SECONDS=${INGRESS_ENDPOINT_RETRY_DELAY_SECONDS}
  --verbose                   Stream full command output
  -h, --help                  Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --cluster-name) CLUSTER_NAME="$2"; shift 2 ;;
    --release-name) RELEASE_NAME="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --bootstrap-config) BOOTSTRAP_CONFIG_PATH="$2"; shift 2 ;;
    --values-file) VALUES_FILES+=("$2"); shift 2 ;;
    --kube-context) KUBE_CONTEXT="$2"; shift 2 ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --remote-docker-secret) REMOTE_DOCKER_SECRET_NAME="$2"; shift 2 ;;
    --remote-docker-host) REMOTE_DOCKER_HOST="$2"; shift 2 ;;
    --remote-docker-port) REMOTE_DOCKER_PORT="$2"; shift 2 ;;
    --remote-docker-key) REMOTE_DOCKER_KEY_PATH="$2"; shift 2 ;;
    --incus-vm-name) INCUS_VM_NAME="$2"; INCUS_CONNECTION_INFO_PATH="${HOME}/.local/state/ai-homebase/incus/${INCUS_VM_NAME}.env"; shift 2 ;;
    --incus-connection-info) INCUS_CONNECTION_INFO_PATH="$2"; shift 2 ;;
    --verbose) BOOTSTRAP_VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

case "$PROFILE" in
  k3d|k3s) ;;
  *) echo "Missing or unsupported --profile. Use k3d or k3s." >&2; usage; exit 1 ;;
esac

if [[ -z "$KUBECONFIG_PATH" ]]; then
  KUBECONFIG_PATH="$(normalize_kubeconfig_path "$RAW_KUBECONFIG")"
fi

DEFAULT_K3D_KUBECONFIG_PATH="${HOME}/.kube/k3d-${CLUSTER_NAME}.yaml"
if [[ "$PROFILE" == "k3d" && -z "$KUBECONFIG_PATH" ]]; then
  if [[ -f "$DEFAULT_K3D_KUBECONFIG_PATH" ]]; then
    KUBECONFIG_PATH="$DEFAULT_K3D_KUBECONFIG_PATH"
  fi
elif [[ "$PROFILE" == "k3d" && "$KUBECONFIG_PATH" == "${HOME}/.kube/config" && -f "$DEFAULT_K3D_KUBECONFIG_PATH" ]]; then
  KUBECONFIG_PATH="$DEFAULT_K3D_KUBECONFIG_PATH"
fi

bootstrap_init_logging

if [[ ${#VALUES_FILES[@]} -eq 0 ]]; then
  VALUES_FILES=("charts/platform-stack/values.yaml")
  if [[ "$PROFILE" == "k3d" ]]; then
    VALUES_FILES+=("charts/platform-stack/values-k3d.yaml")
  else
    VALUES_FILES+=("charts/platform-stack/values-k3s.yaml")
  fi
fi

for cmd in helm kubectl curl python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Missing required dependency: $cmd"
    exit 1
  fi
done

if [[ -f "$BOOTSTRAP_CONFIG_PATH" ]]; then
  BOOTSTRAP_SHELL_VARS="$(python3 ./scripts/bootstrap-config.py shell-vars --config "$BOOTSTRAP_CONFIG_PATH")" || exit 1
  eval "$BOOTSTRAP_SHELL_VARS"
  GITEA_ACTIONS_RUNNER_CONNECTION_INFO_PATH="${HOME}/.local/state/ai-homebase/incus/${GITEA_ACTIONS_RUNNER_VM_NAME}.env"
  GITEA_ACTIONS_RUNNER_KEY_PATH="${HOME}/.local/state/ai-homebase/incus/${GITEA_ACTIONS_RUNNER_VM_NAME}-id_ed25519"
  EXPECTED_DEFAULT_SANDBOX_IMAGE="${OPENCLAW_DEFAULT_SANDBOX_IMAGE:-$EXPECTED_DEFAULT_SANDBOX_IMAGE}"
  EXPECTED_CODER_SANDBOX_IMAGE="${OPENCLAW_CODER_SANDBOX_IMAGE:-$EXPECTED_CODER_SANDBOX_IMAGE}"
fi

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
    hints+=("Missing chart dependencies: run 'helm dependency update charts/gitea' and 'helm dependency update charts/platform-stack' before retrying.")
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
  echo "   ./scripts/bootstrap-smoke.sh --profile ${PROFILE} --release-name ${RELEASE_NAME} --namespace ${NAMESPACE} --verbose" >&2
  echo "2) Inspect namespace resources and events:" >&2
  echo "   kubectl ${KUBECTL_KUBECONFIG_ARGS[*]} ${KUBECTL_CONTEXT_ARGS[*]} -n ${NAMESPACE} get pods,deploy,statefulset,job,ingress" >&2
  echo "   kubectl ${KUBECTL_KUBECONFIG_ARGS[*]} ${KUBECTL_CONTEXT_ARGS[*]} -n ${NAMESPACE} get events --sort-by=.lastTimestamp | tail -n 40" >&2
  echo "3) If Helm failed, refresh dependencies and retry install:" >&2
  echo "   helm dependency update charts/gitea" >&2
  echo "   helm dependency update charts/platform-stack" >&2
  echo "   helm upgrade --install ${RELEASE_NAME} charts/platform-stack --namespace ${NAMESPACE} --create-namespace ${VALUES_ARGS[*]}" >&2
  echo "4) Review full bootstrap log:" >&2
  echo "   less ${BOOTSTRAP_LOG_FILE}" >&2
}

on_error() {
  local line="$1"
  local failed_command="${CURRENT_COMMAND:-${2:-unknown}}"
  fail "Bootstrap smoke checks failed near line ${line}."
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
  local wait_timeout="${2:-600s}"
  local deployment_name
  deployment_name="$(resolve_deployment_name "$app_name")"

  step "Waiting for deployment/${deployment_name} rollout"
  run_checked kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" rollout status "deployment/${deployment_name}" --timeout="$wait_timeout"

  step "Waiting for pods to become Ready (app=${app_name})"
  run_checked kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" wait \
    --for=condition=Ready \
    pod \
    -l "app.kubernetes.io/instance=${RELEASE_NAME},app.kubernetes.io/name=${app_name}" \
    --timeout="$wait_timeout"
}

effective_value() {
  local path="$1"
  helm get values "$RELEASE_NAME" \
    "${HELM_KUBECONFIG_ARGS[@]}" \
    "${HELM_CONTEXT_ARGS[@]}" \
    --namespace "$NAMESPACE" \
    --all \
    --output json | python3 -c '
import json
import sys

def parse_path(raw: str):
    segments = []
    for part in raw.split("."):
        if part.isdigit():
            segments.append(int(part))
        else:
            segments.append(part)
    return segments

path = parse_path(sys.argv[1])
value = json.load(sys.stdin)
for key in path:
    if isinstance(key, int):
        if not isinstance(value, list) or key >= len(value):
            value = ""
            break
        value = value[key]
        continue
    if not isinstance(value, dict):
        value = ""
        break
    value = value.get(key, "")

if isinstance(value, bool):
    print("true" if value else "false")
elif isinstance(value, (str, int, float)):
    print(value)
else:
    print("")
' "$path"
}

effective_bool_value() {
  local path="$1"
  [[ "$(effective_value "$path")" == "true" ]] && echo "true" || echo "false"
}

is_openclaw_ingress_enabled() {
  effective_bool_value "openclaw.ingress.enabled"
}

is_registry_enabled() {
  effective_bool_value "registry.enabled"
}

is_openclaw_remote_docker_enabled() {
  effective_bool_value "openclaw.remoteDocker.enabled"
}

is_gitea_enabled() {
  effective_bool_value "gitea.enabled"
}

is_nextcloud_enabled() {
  effective_bool_value "nextcloud.enabled"
}

is_vaultwarden_enabled() {
  effective_bool_value "vaultwarden.enabled"
}

is_nextcloud_mcp_enabled() {
  effective_bool_value "nextcloudMcp.enabled"
}

is_postfix_relay_enabled() {
  effective_bool_value "postfixRelay.enabled"
}

is_paperless_enabled() {
  effective_bool_value "paperlessNgx.enabled"
}

is_qdrant_enabled() {
  effective_bool_value "qdrant.enabled"
}

is_qdrant_mcp_enabled() {
  effective_bool_value "qdrantMcp.enabled"
}

manifest_named_resources() {
  local kind_filter="$1"
  helm get manifest "$RELEASE_NAME" \
    "${HELM_KUBECONFIG_ARGS[@]}" \
    "${HELM_CONTEXT_ARGS[@]}" \
    --namespace "$NAMESPACE" | python3 -c '
import re
import sys

kind_filter = sys.argv[1]
release_name = sys.argv[2]
text = sys.stdin.read()
for doc in [doc for doc in re.split(r"\n---\n", text) if doc.strip()]:
    kind_match = re.search(r"^kind:\s*(.+)$", doc, re.MULTILINE)
    name_match = re.search(r"^  name:\s*(.+)$", doc, re.MULTILINE)
    if kind_match is None or name_match is None:
        continue
    if kind_match.group(1).strip() != kind_filter:
        continue
    resource_name = name_match.group(1).strip().strip("\"")
    if f"{release_name}-gitea" in resource_name:
        print(resource_name)
        continue
    labels_match = re.search(
        r"^  labels:\n(?P<body>(?:^    .*\n?)*)",
        doc,
        re.MULTILINE,
    )
    labels = labels_match.group("body") if labels_match else ""
    if f"app.kubernetes.io/instance: {release_name}" not in labels:
        continue
    if "app.kubernetes.io/name: gitea" not in labels:
        continue
    print(resource_name)
' "$kind_filter" "$RELEASE_NAME"
}

wait_for_named_resource() {
  local kind="$1"
  local resource_name="$2"
  local wait_seconds="${3:-600}"
  local elapsed=0

  step "Waiting for ${kind,,}/${resource_name} to exist"
  while (( elapsed < wait_seconds )); do
    if kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get "${kind,,}/${resource_name}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done

  fail "Timed out waiting for ${kind,,}/${resource_name} to exist in namespace=${NAMESPACE}"
  return 1
}

wait_for_statefulset() {
  local app_name="$1"
  local wait_timeout="${2:-600s}"
  local statefulset_name

  statefulset_name="$(kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get statefulset \
    -l "app.kubernetes.io/instance=${RELEASE_NAME},app.kubernetes.io/name=${app_name}" \
    -o jsonpath='{.items[0].metadata.name}')"

  if [[ -z "$statefulset_name" ]]; then
    fail "Unable to find statefulset for app=${app_name}, release=${RELEASE_NAME} in namespace=${NAMESPACE}"
    return 1
  fi

  wait_for_named_resource StatefulSet "$statefulset_name"

  step "Waiting for statefulset/${statefulset_name} rollout"
  run_checked kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" rollout status "statefulset/${statefulset_name}" --timeout="$wait_timeout"
}

resolve_statefulset_name() {
  local app_name="$1"
  local statefulset_name
  statefulset_name="$(kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get statefulset \
    -l "app.kubernetes.io/instance=${RELEASE_NAME},app.kubernetes.io/name=${app_name}" \
    -o jsonpath='{.items[0].metadata.name}')"

  if [[ -z "$statefulset_name" ]]; then
    fail "Unable to find statefulset for app=${app_name}, release=${RELEASE_NAME} in namespace=${NAMESPACE}"
    return 1
  fi

  echo "$statefulset_name"
}

wait_for_http_endpoint() {
  local host="$1"
  local url="$2"
  local endpoint_label="$3"
  local attempt=1

  while (( attempt <= INGRESS_ENDPOINT_RETRIES )); do
    if curl --silent --show-error --fail -H "Host: ${host}" "$url" >>"$BOOTSTRAP_LOG_FILE" 2>&1; then
      return 0
    fi
    if (( attempt == INGRESS_ENDPOINT_RETRIES )); then
      break
    fi
    sleep "$INGRESS_ENDPOINT_RETRY_DELAY_SECONDS"
    attempt=$((attempt + 1))
  done

  fail "${endpoint_label} ingress endpoint did not become healthy after ${INGRESS_ENDPOINT_RETRIES} attempts"
  return 1
}

wait_for_gitea_workloads() {
  local wait_timeout="${1:-1200s}"
  local workload_entries=()
  local kind
  local workload_name

  while IFS= read -r workload_name; do
    [[ -n "$workload_name" ]] && workload_entries+=("StatefulSet:${workload_name}")
  done < <(manifest_named_resources StatefulSet)

  while IFS= read -r workload_name; do
    [[ -n "$workload_name" ]] && workload_entries+=("Deployment:${workload_name}")
  done < <(manifest_named_resources Deployment)

  if [[ ${#workload_entries[@]} -eq 0 ]]; then
    fail "Gitea is enabled, but no rendered Deployment/StatefulSet was found for release=${RELEASE_NAME}"
    return 1
  fi

  for entry in "${workload_entries[@]}"; do
    kind="${entry%%:*}"
    workload_name="${entry#*:}"
    wait_for_named_resource "$kind" "$workload_name"
    step "Waiting for ${kind,,}/${workload_name} rollout"
    run_checked kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" rollout status "${kind,,}/${workload_name}" --timeout="$wait_timeout"
  done
}

verify_gitea_services() {
  local service_names=()
  local service_name

  while IFS= read -r service_name; do
    [[ -n "$service_name" ]] && service_names+=("$service_name")
  done < <(manifest_named_resources Service)

  if [[ ${#service_names[@]} -eq 0 ]]; then
    fail "Gitea is enabled, but no rendered Service was found for release=${RELEASE_NAME}"
    return 1
  fi

  for service_name in "${service_names[@]}"; do
    wait_for_named_resource Service "$service_name"
  done

  ok "Validated ${#service_names[@]} Gitea Service resource(s)"
}

verify_registry_services() {
  wait_for_workload registry "$GITEA_WAIT_TIMEOUT"
  verify_labeled_service registry
  kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" \
    get ingress "${RELEASE_NAME}-registry" >/dev/null
}

verify_labeled_service() {
  local app_name="$1"
  local service_name

  service_name="$(kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get service \
    -l "app.kubernetes.io/instance=${RELEASE_NAME},app.kubernetes.io/name=${app_name}" \
    -o jsonpath='{.items[0].metadata.name}')"

  if [[ -z "$service_name" ]]; then
    fail "Unable to find Service for app=${app_name}, release=${RELEASE_NAME} in namespace=${NAMESPACE}"
    return 1
  fi

  wait_for_named_resource Service "$service_name"
}

verify_openclaw_remote_docker() {
  local deployment_name="$1"
  local effective_docker_host
  effective_docker_host="$(effective_value "openclaw.remoteDocker.dockerHost")"

  step "Checking OpenClaw remote Docker connectivity"
  CURRENT_COMMAND="kubectl exec deployment/${deployment_name} -- sh -ceu 'command -v docker && command -v ssh && docker info'"
  run_checked kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" exec "deployment/${deployment_name}" -- sh -ceu "
    command -v docker >/dev/null
    command -v ssh >/dev/null
    [ \"\${DOCKER_HOST:-}\" = \"$effective_docker_host\" ]
    docker info >/dev/null
    config_path=\"\${OPENCLAW_CONFIG_PATH:-}\"
    [ -n \"\$config_path\" ]
    [ -f \"\$config_path\" ]
    tr -d '[:space:]' <\"\$config_path\" | grep -F '\"backend\":\"docker\"' >/dev/null
  "
}

verify_openclaw_gateway_tooling() {
  local deployment_name="$1"
  local expected_reviewer_host="${RELEASE_NAME}-gitea-http.${NAMESPACE}.svc.cluster.local"
  local expected_reviewer_base_url="http://${expected_reviewer_host}:3000"
  local expected_xdg_config_home="/home/node/.openclaw/.config"
  local expected_xdg_cache_home="/home/node/.openclaw/.cache"
  local expected_xdg_state_home="/home/node/.openclaw/.local/state"
  local expected_git_config_global="/home/node/.openclaw/.config/git/config"
  local expected_repo_url="${expected_reviewer_base_url}/${CODER_GITEA_USERNAME}/${GITOPS_REPO_NAME}.git"
  local coder_workspace_home="/home/node/.openclaw/workspace-coder/.home"
  local reviewer_workspace_homes="/home/node/.openclaw/workspace-architect/.home /home/node/.openclaw/workspace-auditor/.home"

  step "Checking OpenClaw gateway tooling and seeded coder/reviewer auth state"
  CURRENT_COMMAND="kubectl exec deployment/${deployment_name} -- sh -ceu 'check gateway tooling plus seeded coder and reviewer auth state'"
  run_checked kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" exec "deployment/${deployment_name}" -- sh -ceu "
    command -v jq >/dev/null
    command -v rg >/dev/null
    command -v python3 >/dev/null
    command -v tokscale >/dev/null
    command -v tea >/dev/null
    [ \"\${REVIEWER_GITEA_HOST:-}\" = \"${expected_reviewer_host}\" ]
    [ \"\${REVIEWER_GITEA_BASE_URL:-}\" = \"${expected_reviewer_base_url}\" ]
    [ \"\${XDG_CONFIG_HOME:-}\" = \"${expected_xdg_config_home}\" ]
    [ \"\${XDG_CACHE_HOME:-}\" = \"${expected_xdg_cache_home}\" ]
    [ \"\${XDG_STATE_HOME:-}\" = \"${expected_xdg_state_home}\" ]
    [ \"\${GIT_CONFIG_GLOBAL:-}\" = \"${expected_git_config_global}\" ]
    test -L /home/node/.tea
    test -L /home/node/.gitconfig
    test -f \"${expected_git_config_global}\"
    test -d \"${expected_xdg_config_home}/tea\"
    tea login list | grep -F \"reviewer\" >/dev/null
    tea login list | grep -F 'true' >/dev/null
    tea repo list 2>&1 | grep -F \"cluster-gitops\" >/dev/null
    ! tea repo list 2>&1 | grep -F \"falling back to login\" >/dev/null
    git ls-remote \"${expected_repo_url}\" >/dev/null
    git ls-remote \"git@${GITEA_INGRESS_HOST}:${CODER_GITEA_USERNAME}/${GITOPS_REPO_NAME}.git\" >/dev/null
    test -f \"${coder_workspace_home}/.codex/auth.json\"
    grep -F '\"auth_mode\": \"apikey\"' \"${coder_workspace_home}/.codex/auth.json\" >/dev/null
    test -f \"${coder_workspace_home}/.config/tea/config.yml\"
    grep -F 'name: coder' \"${coder_workspace_home}/.config/tea/config.yml\" >/dev/null
    grep -F 'url: ${expected_reviewer_base_url}' \"${coder_workspace_home}/.config/tea/config.yml\" >/dev/null
    grep -F 'default: true' \"${coder_workspace_home}/.config/tea/config.yml\" >/dev/null
    env \
      HOME=\"${coder_workspace_home}\" \
      XDG_CONFIG_HOME=\"${coder_workspace_home}/.config\" \
      XDG_CACHE_HOME=\"${coder_workspace_home}/.cache\" \
      XDG_STATE_HOME=\"${coder_workspace_home}/.local/state\" \
      tea repo list --login coder | grep -F \"cluster-gitops\" >/dev/null
    test -f \"${coder_workspace_home}/.docker/config.json\"
    for reviewer_workspace_home in ${reviewer_workspace_homes}; do
      test -f \"\${reviewer_workspace_home}/.config/tea/config.yml\"
      grep -F 'name: reviewer' \"\${reviewer_workspace_home}/.config/tea/config.yml\" >/dev/null
      grep -F 'url: ${expected_reviewer_base_url}' \"\${reviewer_workspace_home}/.config/tea/config.yml\" >/dev/null
      grep -F 'default: true' \"\${reviewer_workspace_home}/.config/tea/config.yml\" >/dev/null
      env \
        HOME=\"\${reviewer_workspace_home}\" \
        XDG_CONFIG_HOME=\"\${reviewer_workspace_home}/.config\" \
        XDG_CACHE_HOME=\"\${reviewer_workspace_home}/.cache\" \
        XDG_STATE_HOME=\"\${reviewer_workspace_home}/.local/state\" \
        GIT_CONFIG_GLOBAL=\"\${reviewer_workspace_home}/.config/git/config\" \
        sh -ceu '
          tea repo list 2>&1 | grep -F "cluster-gitops" >/dev/null
          ! tea repo list 2>&1 | grep -F "falling back to login" >/dev/null
        '
    done
    python3 - <<'PY'
import json
from pathlib import Path

config = json.loads(Path('${coder_workspace_home}/.docker/config.json').read_text())
auths = config.get('auths', {})
if '${REGISTRY_INGRESS_HOST}' not in auths:
    raise SystemExit('missing registry auth for coder workspace')
PY
  "
}

verify_openclaw_mcp_bootstrap_config() {
  local configmap_name="$1"
  local deployment_name="$2"
  local openclaw_json=""
  local cron_jobs_json=""
  local architect_reviewer_scheme="https"
  local architect_reviewer_base_url=""

  if [[ "${GITEA_INGRESS_HOST:-}" == *.localtest.me ]]; then
    architect_reviewer_scheme="http"
  fi
  architect_reviewer_base_url="${architect_reviewer_scheme}://${GITEA_INGRESS_HOST}"

  openclaw_json="$(
    kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get configmap "$configmap_name" -o jsonpath='{.data.openclaw\.json}'
  )"

  if [[ "$openclaw_json" != *'${OPENCLAW_NEXTCLOUD_MCP_INTERNAL_URL}'* ]]; then
    fail "OpenClaw bootstrap config in ConfigMap/${configmap_name} is missing the internal Nextcloud MCP URL placeholder"
    exit 1
  fi

  if [[ "$openclaw_json" != *'${OPENCLAW_NEXTCLOUD_MCP_EXTERNAL_URL}'* ]]; then
    fail "OpenClaw bootstrap config in ConfigMap/${configmap_name} is missing the external Nextcloud MCP URL placeholder"
    exit 1
  fi

  if [[ "$openclaw_json" != *'"enabled":true'* ]]; then
    fail "OpenClaw bootstrap config in ConfigMap/${configmap_name} is missing the cron.enabled setting"
    exit 1
  fi

  if [[ "$openclaw_json" != *'"store":"~/.openclaw/cron/jobs.json"'* ]]; then
    fail "OpenClaw bootstrap config in ConfigMap/${configmap_name} is missing the documented cron store path"
    exit 1
  fi

  if [[ -z "$EXPECTED_DEFAULT_SANDBOX_IMAGE" ]]; then
    EXPECTED_DEFAULT_SANDBOX_IMAGE="${REGISTRY_INGRESS_HOST}/openclaw/openclaw-sandbox:trixie-slim"
  fi
  if [[ "$openclaw_json" != *"${EXPECTED_DEFAULT_SANDBOX_IMAGE}"* ]]; then
    fail "OpenClaw bootstrap config in ConfigMap/${configmap_name} is not using the canonical registry-backed default sandbox image"
    exit 1
  fi

  if [[ -z "$EXPECTED_CODER_SANDBOX_IMAGE" ]]; then
    EXPECTED_CODER_SANDBOX_IMAGE="${REGISTRY_INGRESS_HOST}/openclaw/openclaw-sandbox-coder:trixie-slim"
  fi
  if [[ "$openclaw_json" != *"${EXPECTED_CODER_SANDBOX_IMAGE}"* ]]; then
    fail "OpenClaw bootstrap config in ConfigMap/${configmap_name} is not using the canonical registry-backed coder sandbox image"
    exit 1
  fi

  if [[ "$openclaw_json" != *'"/workspace/.openclaw-runtime/ai-homebase-ca-bundle.crt"'* ]]; then
    fail "OpenClaw bootstrap config in ConfigMap/${configmap_name} is not using the workspace-local sandbox CA bundle path"
    exit 1
  fi

  if [[ "$openclaw_json" != *'"HOME":"/workspace/.home"'* ]]; then
    fail "OpenClaw bootstrap config in ConfigMap/${configmap_name} is not keeping regular sandbox home state under /workspace/.home"
    exit 1
  fi

  if [[ "$openclaw_json" == *'/home/node/.openclaw/certs/ai-homebase-ca-bundle.crt:/etc/ssl/certs/ai-homebase-ca-bundle.crt:ro'* ]]; then
    fail "OpenClaw bootstrap config in ConfigMap/${configmap_name} still contains the retired out-of-roots sandbox CA bind mount"
    exit 1
  fi

  if [[ "$openclaw_json" == *'/var/run/docker.sock:/var/run/docker.sock'* ]]; then
    fail "OpenClaw bootstrap config in ConfigMap/${configmap_name} still contains the retired Docker socket bind mount"
    exit 1
  fi

  if [[ "$openclaw_json" != *'"DOCKER_HOST":"${DOCKER_HOST}"'* ]]; then
    fail "OpenClaw bootstrap config in ConfigMap/${configmap_name} is not wiring coder to inherit the remote Docker endpoint from gateway env"
    exit 1
  fi

  if [[ "$openclaw_json" != *'"CODER_GITEA_TOKEN":"${CODER_GITEA_TOKEN}"'* ]]; then
    fail "OpenClaw bootstrap config in ConfigMap/${configmap_name} is not wiring coder tea token interpolation from gateway env"
    exit 1
  fi

  if [[ "$openclaw_json" != *"\"CODER_GITEA_TEA_URL\":\"${architect_reviewer_base_url}\""* ]]; then
    fail "OpenClaw bootstrap config in ConfigMap/${configmap_name} is not keeping coder sandbox tea access on the ingress hostname path"
    exit 1
  fi

  if [[ "$openclaw_json" != *'"name":"CODER_GITEA_TEA_URL","value":"'"${architect_reviewer_base_url}"'"'* ]]; then
    fail "OpenClaw gateway env in ConfigMap/${configmap_name} is not seeding coder workspace tea login against the ingress hostname path"
    exit 1
  fi

  if [[ "$openclaw_json" != *'"REVIEWER_GITEA_TOKEN":"${REVIEWER_GITEA_TOKEN}"'* ]]; then
    fail "OpenClaw bootstrap config in ConfigMap/${configmap_name} is not wiring reviewer tea token interpolation from gateway env"
    exit 1
  fi

  if [[ "$openclaw_json" != *'"id":"architect"'*'"mode":"non-main"'* ]]; then
    fail "OpenClaw bootstrap config in ConfigMap/${configmap_name} is not keeping architect main sessions on the gateway"
    exit 1
  fi

  if [[ "$openclaw_json" != *"\"REVIEWER_GITEA_BASE_URL\":\"${architect_reviewer_base_url}\""* ]]; then
    fail "OpenClaw bootstrap config in ConfigMap/${configmap_name} is not keeping architect reviewer access on the ingress hostname path"
    exit 1
  fi

  if [[ "$openclaw_json" != *"\"REVIEWER_GITEA_TEA_URL\":\"${architect_reviewer_base_url}\""* ]]; then
    fail "OpenClaw bootstrap config in ConfigMap/${configmap_name} is not keeping architect tea access on the ingress hostname path"
    exit 1
  fi

  if [[ "$openclaw_json" != *'"GIT_CONFIG_GLOBAL":"/workspace/.home/.config/git/config"'* ]]; then
    fail "OpenClaw bootstrap config in ConfigMap/${configmap_name} is not wiring architect sandbox git config into the shared workspace home"
    exit 1
  fi

  if [[ "$openclaw_json" != *"\"REVIEWER_GITEA_HOST\":\"${GITEA_INGRESS_HOST}\""* ]]; then
    fail "OpenClaw bootstrap config in ConfigMap/${configmap_name} is not rendering architect reviewer host routing from the configured Gitea ingress hostname"
    exit 1
  fi

  if [[ "$openclaw_json" != *'"id":"auditor"'*'"mode":"off"'* ]]; then
    fail "OpenClaw bootstrap config in ConfigMap/${configmap_name} is not keeping auditor on the gateway"
    exit 1
  fi

  if ! kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" \
    exec "deployment/${deployment_name}" -- sh -lc '[ -n "${CODER_GITEA_TOKEN:-}" ]'; then
    fail "OpenClaw deployment/${deployment_name} is still missing a live CODER_GITEA_TOKEN env value after bootstrap"
    exit 1
  fi

  if ! kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" \
    exec "deployment/${deployment_name}" -- sh -lc '[ -n "${REVIEWER_GITEA_TOKEN:-}" ]'; then
    fail "OpenClaw deployment/${deployment_name} is still missing a live REVIEWER_GITEA_TOKEN env value after bootstrap"
    exit 1
  fi

  cron_jobs_json="$(
    kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" exec "deployment/${deployment_name}" -- openclaw cron list --json
  )"

  if ! OPENCLAW_CRON_JOBS_JSON="$cron_jobs_json" python3 - <<'PY'
import json
import os
import sys

raw = os.environ["OPENCLAW_CRON_JOBS_JSON"]
start = None
for index, char in enumerate(raw):
    if char in "[{":
        start = index
        break
if start is None:
    raise SystemExit("missing JSON payload from openclaw cron list --json")
payload = json.loads(raw[start:])
jobs = payload if isinstance(payload, list) else payload.get("jobs", [])
names = {job.get("name") for job in jobs}
expected = {
    "Watchdog platform sweep",
    "Watchdog nightly activity check",
    "Watchdog daily digest",
    "Archivist weekly graph grooming",
    "Auditor weekly review",
    "Watchdog daily wrap-up",
    "Architect daily wrap-up",
    "Archivist daily wrap-up",
    "Auditor daily wrap-up",
    "Main daily wrap-up",
}
forbidden = {"Archivist nightly grooming"}
if not expected.issubset(names):
    missing = ", ".join(sorted(expected - names))
    raise SystemExit(f"missing cron jobs: {missing}")
if forbidden & names:
    present = ", ".join(sorted(forbidden & names))
    raise SystemExit(f"unexpected retired cron jobs present: {present}")
PY
  then
    fail "OpenClaw gateway is missing one or more seeded cron jobs"
    exit 1
  fi
}

verify_openclaw_workspace_bootstrap() {
  local deployment_name="$1"

  step "Checking bootstrapped OpenClaw workspace files"
  CURRENT_COMMAND="kubectl exec deployment/${deployment_name} -- sh -ceu 'test workspace bootstrap files'"
  run_checked kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" exec "deployment/${deployment_name}" -- sh -ceu '
    jq -e '"'"'.agents.defaults.heartbeat.every == "0m"'"'"' /home/node/.openclaw/openclaw.json >/dev/null
    jq -e '"'"'.agents.list[] | select(.id=="main") | .heartbeat.every == "0m" and .heartbeat.includeSystemPromptSection == false'"'"' /home/node/.openclaw/openclaw.json >/dev/null
    jq -e '"'"'[.agents.list[] | select(.id != "watchdog") | select(.heartbeat.every? != null and .heartbeat.every != "0m")] | length == 0'"'"' /home/node/.openclaw/openclaw.json >/dev/null
    jq -e '"'"'.agents.list[] | select(.id=="watchdog") | .heartbeat.every == "30m"'"'"' /home/node/.openclaw/openclaw.json >/dev/null

    test -f /home/node/.openclaw/workspace/BOOTSTRAP.md
    grep -F "agent:auditor:main" /home/node/.openclaw/workspace/BOOTSTRAP.md >/dev/null

    test -f /home/node/.openclaw/workspace/AGENTS.md
    grep -F "systemic quality judgment -> \`auditor\`" /home/node/.openclaw/workspace/AGENTS.md >/dev/null
    grep -F "choose an execution mode first: \`spec-first\` or \`direct-build\`" /home/node/.openclaw/workspace/AGENTS.md >/dev/null
    test -f /home/node/.openclaw/workspace/.openclaw-runtime/ai-homebase-ca-bundle.crt

    test -f /home/node/.openclaw/workspace-coder/TOOLS.md
    grep -F "CODER_GITEA_BASE_URL" /home/node/.openclaw/workspace-coder/TOOLS.md >/dev/null
    grep -F "/Projects/ai-homebase/codex-usage/" /home/node/.openclaw/workspace-coder/TOOLS.md >/dev/null
    grep -F "start Codex from the target repo root under \`/workspace\`" /home/node/.openclaw/workspace-coder/skills/manage-gitea-gitops-and-registry/SKILL.md >/dev/null
    ! grep -F "AGENTS.md" /home/node/.openclaw/workspace-coder/skills/manage-gitea-gitops-and-registry/SKILL.md >/dev/null
    ! grep -F "./scripts/lint.sh" /home/node/.openclaw/workspace-coder/skills/manage-gitea-gitops-and-registry/SKILL.md >/dev/null
    test -f /home/node/.openclaw/workspace-coder/skills/run-codex-and-log-usage/SKILL.md
    grep -F "default \`gpt-5.4-mini\` for routine work" /home/node/.openclaw/workspace-coder/skills/run-codex-and-log-usage/SKILL.md >/dev/null
    test -f /home/node/.openclaw/workspace/skills/handoff-specialist-work/SKILL.md
    grep -F "Do not request an architect spec and coder implementation in parallel for the same change." /home/node/.openclaw/workspace/skills/handoff-specialist-work/SKILL.md >/dev/null
    test -f /home/node/.openclaw/workspace-coder/.openclaw-runtime/ai-homebase-ca-bundle.crt
    test -f /home/node/.openclaw/workspace-coder/.home/.ssh/id_ed25519
    test -f /home/node/.openclaw/workspace-coder/.home/.ssh/known_hosts

    test -f /home/node/.openclaw/workspace-archivist/TOOLS.md
    grep -F "MEMGRAPH_BOLT_URI" /home/node/.openclaw/workspace-archivist/TOOLS.md >/dev/null
    grep -F "state/grooming-checkpoint.json" /home/node/.openclaw/workspace-archivist/TOOLS.md >/dev/null
    grep -F "QDRANT_URL" /home/node/.openclaw/workspace-archivist/TOOLS.md >/dev/null
    test -f /home/node/.openclaw/workspace-archivist/qdrant/scroll_memories.py
    test -f /home/node/.openclaw/workspace-archivist/qdrant/get_memory.py
    test -f /home/node/.openclaw/workspace-archivist/qdrant/set_graph_link.py
    test -f /home/node/.openclaw/workspace-archivist/qdrant/README.md
    test -f /home/node/.openclaw/workspace-archivist/state/grooming-checkpoint.json
    grep -F "\"last_successful_graph_link\"" /home/node/.openclaw/workspace-archivist/state/grooming-checkpoint.json >/dev/null
    test ! -e /home/node/.openclaw/workspace-archivist/state/grooming-cursor.json
    test ! -e /home/node/.openclaw/workspace-archivist/state/qdrant-graph-link-cursor.json
    test -f /home/node/.openclaw/workspace-archivist/grooming/update_checkpoint.py
    test -f /home/node/.openclaw/workspace-archivist/queries/README.md
    test -f /home/node/.openclaw/workspace-archivist/queries/run_query.py
    grep -F "Use \`queries/run_query.py\` for parameterized helpers" /home/node/.openclaw/workspace-archivist/queries/README.md >/dev/null
    test -f /home/node/.openclaw/workspace-archivist/skills/curate-memgraph/SKILL.md
    grep -F "slug \`qdrant:<point_id>\`" /home/node/.openclaw/workspace-archivist/skills/curate-memgraph/SKILL.md >/dev/null
    test -f /home/node/.openclaw/workspace-archivist/queries/entity-by-slug.cypher
    test -f /home/node/.openclaw/workspace-archivist/queries/upsert-memory-entry.cypher
    test -f /home/node/.openclaw/workspace-archivist/queries/link-memory-to-entity.cypher
    test -f /home/node/.openclaw/workspace-archivist/.openclaw-runtime/ai-homebase-ca-bundle.crt

    test -f /home/node/.openclaw/workspace-architect/AGENTS.md
    grep -F "verdicts -> auditor" /home/node/.openclaw/workspace-architect/AGENTS.md >/dev/null
    test -f /home/node/.openclaw/workspace-architect/.openclaw-runtime/ai-homebase-ca-bundle.crt
    grep -F "Do not push branches, open pull requests, create commits, merge, or modify repo state." /home/node/.openclaw/workspace-architect/skills/gitea-browse/SKILL.md >/dev/null
    grep -F "mktemp -d" /home/node/.openclaw/workspace-architect/skills/gitea-browse/SKILL.md >/dev/null
    grep -F "\${REVIEWER_GITEA_BASE_URL%/}/<owner>/<repo>.git" /home/node/.openclaw/workspace-architect/skills/gitea-browse/SKILL.md >/dev/null

    test -f /home/node/.openclaw/workspace-watchdog/AGENTS.md
    grep -F "systemic review -> auditor" /home/node/.openclaw/workspace-watchdog/AGENTS.md >/dev/null
    test -f /home/node/.openclaw/workspace-watchdog/HEARTBEAT.md
    grep -F "## Heartbeat Procedure" /home/node/.openclaw/workspace-watchdog/HEARTBEAT.md >/dev/null
    test -f /home/node/.openclaw/workspace-watchdog/.openclaw-runtime/ai-homebase-ca-bundle.crt
    test -f /home/node/.openclaw/workspace-watchdog/TOOLS.md
    grep -F "http://127.0.0.1:18789/readyz" /home/node/.openclaw/workspace-watchdog/TOOLS.md >/dev/null
    test -f /home/node/.openclaw/workspace-watchdog/skills/check-heartbeat-and-budget/SKILL.md
    grep -F "Heartbeat And Budget Sentinel" /home/node/.openclaw/workspace-watchdog/skills/check-heartbeat-and-budget/SKILL.md >/dev/null

    test -f /home/node/.openclaw/workspace-auditor/MEMORY.md
    grep -F "\"agent\":\"auditor\"" /home/node/.openclaw/workspace-auditor/MEMORY.md >/dev/null
    test -f /home/node/.openclaw/workspace-auditor/.openclaw-runtime/ai-homebase-ca-bundle.crt
    grep -F "Merge only when main or the user explicitly instructs you to merge." /home/node/.openclaw/workspace-auditor/skills/gitea-browse/SKILL.md >/dev/null
    grep -F "mktemp -d" /home/node/.openclaw/workspace-auditor/skills/gitea-browse/SKILL.md >/dev/null
    grep -F "\${REVIEWER_GITEA_BASE_URL%/}/<owner>/<repo>.git" /home/node/.openclaw/workspace-auditor/skills/gitea-browse/SKILL.md >/dev/null
  '
}

verify_nextcloud_bootstrap_content() {
  local statefulset_name="$1"

  step "Checking Nextcloud bootstrap project content"
  CURRENT_COMMAND="kubectl exec statefulset/${statefulset_name} -- sh -ceu 'test Nextcloud bootstrap content'"
  run_checked kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" exec "statefulset/${statefulset_name}" -- sh -ceu '
    project_root=/var/www/html/data/openclaw/files/Projects/ai-homebase

    [ "$(stat -c "%U:%G" /var/www/html/data/openclaw/files)" = "www-data:www-data" ]
    [ "$(stat -c "%U:%G" /var/www/html/data/openclaw/files/Projects)" = "www-data:www-data" ]
    test -f "${project_root}/coordination-status.json"
    grep -F "\"agent\"" "${project_root}/coordination-status.json" >/dev/null
    grep -F "\"status\"" "${project_root}/coordination-status.json" >/dev/null
    test -f "${project_root}/knowledge-graph-schema.md"
    grep -F "MemoryEntry" "${project_root}/knowledge-graph-schema.md" >/dev/null
    test -f "${project_root}/archivist-grooming-log.md"
    test -f "${project_root}/audit-log.md"
    test -f "${project_root}/watchdog-status-log.md"
    test -f "${project_root}/codex-usage/.gitkeep"
    test ! -e "${project_root}/budget-ledger.json"

    test -f "${project_root}/automation-backlog.md"
  '
}

verify_qdrant_mcp_runtime() {
  local deployment_name="$1"

  step "Checking Qdrant MCP runtime configuration"
  CURRENT_COMMAND="kubectl exec deployment/${deployment_name} -- sh -ceu 'check Qdrant MCP env'"
  run_checked kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" exec "deployment/${deployment_name}" -- sh -ceu '
    [ "${QDRANT_ALLOW_ARBITRARY_FILTER:-}" = "true" ]
    printf "%s" "${TOOL_FIND_DESCRIPTION:-}" | grep -F "query_filter" >/dev/null
    printf "%s" "${TOOL_FIND_DESCRIPTION:-}" | grep -F "metadata.created" >/dev/null
    printf "%s" "${TOOL_FIND_DESCRIPTION:-}" | grep -F "metadata.project" >/dev/null
    printf "%s" "${TOOL_STORE_DESCRIPTION:-}" | grep -F "atomic durable claim" >/dev/null
  '
}

verify_memgraph_bootstrap() {
  local deployment_name="$1"

  step "Checking Memgraph bootstrap seed state"
  CURRENT_COMMAND="kubectl exec deployment/${deployment_name} -- sh -ceu 'run Memgraph bootstrap queries'"
  run_checked kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" exec "deployment/${deployment_name}" -- sh -ceu "
    auditor_count=\$(printf \"MATCH (:Entity:Agent {slug: 'auditor'}) RETURN count(*) AS count;\\n\" | mgconsole --host 127.0.0.1 --port 7687 --output-format csv | tail -n +2 | tr -d '\"[:space:]')
    [ \"\$auditor_count\" = \"1\" ]

    repo_count=\$(printf \"MATCH (:Entity:Work {slug: 'cluster-gitops'}) RETURN count(*) AS count;\\n\" | mgconsole --host 127.0.0.1 --port 7687 --output-format csv | tail -n +2 | tr -d '\"[:space:]')
    [ \"\$repo_count\" = \"1\" ]

    edge_count=\$(printf \"MATCH (:Entity:Service {slug: 'openclaw'})-[r:HAS_PART {kind: 'agent'}]->(:Entity:Agent {slug: 'auditor'}) RETURN count(r) AS count;\\n\" | mgconsole --host 127.0.0.1 --port 7687 --output-format csv | tail -n +2 | tr -d '\"[:space:]')
    [ \"\$edge_count\" = \"1\" ]
  "
}

verify_gateway_memgraph_runtime() {
  local deployment_name="$1"
  local expected_host="${RELEASE_NAME}-memgraph"

  step "Checking gateway Memgraph runtime env"
  CURRENT_COMMAND="kubectl exec deployment/${deployment_name} -- sh -ceu 'check gateway Memgraph env'"
  run_checked kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" exec "deployment/${deployment_name}" -- sh -ceu "
    [ \"\$MEMGRAPH_HOST\" = \"${expected_host}\" ]
    [ \"\$MEMGRAPH_PORT\" = \"7687\" ]
    [ \"\$MEMGRAPH_BOLT_URI\" = \"bolt://${expected_host}:7687\" ]
  "
}

verify_coder_sandbox_runtime() {
  local memgraph_host="$1"

  if ! command -v incus >/dev/null 2>&1; then
    warn "Skipping coder sandbox runtime checks because incus is not installed in the current shell"
    return 0
  fi

  step "Checking coder sandbox runtime image on the Incus Docker host"
  CURRENT_COMMAND="incus exec ${INCUS_VM_NAME} -- sh -ceu 'docker run coder sandbox validation'"
  run_checked incus exec "$INCUS_VM_NAME" -- sh -ceu "
    docker image inspect openclaw-sandbox-coder:trixie-slim >/dev/null
    docker run --rm --entrypoint sh \
      -e HOME=/workspace/.home \
      -e CODEX_HOME=/workspace/.home/.codex \
      -e XDG_CONFIG_HOME=/workspace/.home/.config \
      -e XDG_CACHE_HOME=/workspace/.home/.cache \
      -e XDG_STATE_HOME=/workspace/.home/.local/state \
      -e CODER_GITEA_BASE_URL=https://gitea.example.invalid \
      -e CODER_GITEA_TOKEN=test-coder-token \
      -e CODEX_DEFAULT_MODEL=gpt-5.4-mini \
      -e OPENAI_API_KEY=test-openai-key \
      openclaw-sandbox-coder:trixie-slim -ceu '
        getent passwd sandbox | cut -d: -f6 | grep -Fx /workspace/.home >/dev/null
        test -w /workspace/.home
        command -v codex >/dev/null
        codex --version | grep -F codex-cli >/dev/null
        command -v tea >/dev/null
        ! tea --version | grep -F -- -dev >/dev/null
        command -v tokscale >/dev/null
        /usr/local/bin/coder-init.sh >/tmp/coder-init.log
        test -f /workspace/.home/.codex/config.toml
        grep -F \"approval_policy = \\\"never\\\"\" /workspace/.home/.codex/config.toml >/dev/null
        grep -F \"sandbox_mode = \\\"danger-full-access\\\"\" /workspace/.home/.codex/config.toml >/dev/null
        grep -F \"model = \\\"gpt-5.4-mini\\\"\" /workspace/.home/.codex/config.toml >/dev/null
        grep -F \"forced_login_method = \\\"api\\\"\" /workspace/.home/.codex/config.toml >/dev/null
        test -f /workspace/.home/.codex/auth.json
        test -d /workspace/.home/.config/tea
      '
  "
}

verify_reviewer_sandbox_runtime() {
  local reviewer_scheme="https"
  local reviewer_base_url=""
  local reviewer_token=""

  if ! command -v incus >/dev/null 2>&1; then
    warn "Skipping reviewer sandbox runtime checks because incus is not installed in the current shell"
    return 0
  fi

  if [[ "${GITEA_INGRESS_HOST:-}" == *.localtest.me ]]; then
    reviewer_scheme="http"
  fi
  reviewer_base_url="${reviewer_scheme}://${GITEA_INGRESS_HOST}"
  reviewer_token="$(
    kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" \
      get secret reviewer-credentials -o jsonpath='{.data.REVIEWER_GITEA_TOKEN}' | base64 -d
  )"
  if [[ -z "${reviewer_token}" ]]; then
    fail "reviewer-credentials Secret is missing REVIEWER_GITEA_TOKEN for sandbox smoke checks"
    exit 1
  fi

  step "Checking reviewer sandbox runtime image on the Incus Docker host"
  CURRENT_COMMAND="incus exec ${INCUS_VM_NAME} -- sh -ceu 'docker run reviewer sandbox validation'"
  run_checked incus exec "$INCUS_VM_NAME" -- sh -ceu "
    docker image inspect openclaw-sandbox:trixie-slim >/dev/null
    tmpdir=\$(mktemp -d)
    trap 'rm -rf \"\$tmpdir\"' EXIT
    chown 1000:1000 \"\$tmpdir\"
    chmod 0755 \"\$tmpdir\"
    mkdir -p \"\$tmpdir/.home\"
    chown 1000:1000 \"\$tmpdir/.home\"
    chmod 0755 \"\$tmpdir/.home\"
    mkdir -p \"\$tmpdir/.openclaw-runtime\"
    cp /home/node/.openclaw/certs/ai-homebase-ca-bundle.crt \"\$tmpdir/.openclaw-runtime/ai-homebase-ca-bundle.crt\"
    chown -R 1000:1000 \"\$tmpdir/.openclaw-runtime\"
    chmod 0755 \"\$tmpdir/.openclaw-runtime\"
    chmod 0644 \"\$tmpdir/.openclaw-runtime/ai-homebase-ca-bundle.crt\"
    docker run --rm --entrypoint sh \
      -v \"\$tmpdir:/workspace\" \
      -e HOME=/workspace/.home \
      -e XDG_CONFIG_HOME=/workspace/.home/.config \
      -e XDG_CACHE_HOME=/workspace/.home/.cache \
      -e XDG_STATE_HOME=/workspace/.home/.local/state \
      -e GIT_CONFIG_GLOBAL=/workspace/.home/.config/git/config \
      -e SSL_CERT_FILE=/workspace/.openclaw-runtime/ai-homebase-ca-bundle.crt \
      -e REQUESTS_CA_BUNDLE=/workspace/.openclaw-runtime/ai-homebase-ca-bundle.crt \
      -e NODE_EXTRA_CA_CERTS=/workspace/.openclaw-runtime/ai-homebase-ca-bundle.crt \
      -e GIT_SSL_CAINFO=/workspace/.openclaw-runtime/ai-homebase-ca-bundle.crt \
      -e CURL_CA_BUNDLE=/workspace/.openclaw-runtime/ai-homebase-ca-bundle.crt \
      -e REVIEWER_GITEA_BASE_URL=${reviewer_base_url} \
      -e REVIEWER_GITEA_HOST=${GITEA_INGRESS_HOST} \
      -e REVIEWER_GITEA_TOKEN=${reviewer_token} \
      -e REVIEWER_GITEA_USERNAME=${REVIEWER_GITEA_USERNAME} \
      -e REVIEWER_GITEA_EMAIL=${REVIEWER_GITEA_EMAIL} \
      -e REVIEWER_GITEA_TEA_LOGIN_NAME=reviewer \
      openclaw-sandbox:trixie-slim -ceu '
        getent passwd sandbox | cut -d: -f6 | grep -Fx /workspace/.home >/dev/null
        test -w /workspace/.home
        command -v tea >/dev/null
        ! tea --version | grep -F -- -dev >/dev/null
        /usr/local/bin/reviewer-gitea-init.sh >/tmp/reviewer-gitea-init.log
        test -d /workspace/.home/.tea
        test -d /workspace/.home/.config/tea
        tea login list | grep -F reviewer >/dev/null
        tea repo list 2>&1 | grep -F cluster-gitops >/dev/null
        ! tea repo list 2>&1 | grep -F "falling back to login" >/dev/null
        test -f /workspace/.home/.config/git/config
        git ls-remote "git@'"${GITEA_INGRESS_HOST}"':'"${CODER_GITEA_USERNAME}"'/'"${GITOPS_REPO_NAME}"'.git" >/dev/null
      '
  "
}

verify_gateway_qdrant_runtime() {
  local deployment_name="$1"
  local expected_url="http://${RELEASE_NAME}-qdrant.${NAMESPACE}.svc.cluster.local:6333"

  step "Checking gateway Qdrant runtime env and archivist scripts"
  CURRENT_COMMAND="kubectl exec deployment/${deployment_name} -- sh -ceu 'check gateway Qdrant env and scripts'"
  run_checked kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" exec "deployment/${deployment_name}" -- sh -ceu "
    [ \"\$QDRANT_URL\" = \"${expected_url}\" ]
    [ \"\$QDRANT_COLLECTION\" = \"openclaw-memory\" ]
    python3 -m py_compile \
      /home/node/.openclaw/workspace-archivist/qdrant/_qdrant_common.py \
      /home/node/.openclaw/workspace-archivist/qdrant/scroll_memories.py \
      /home/node/.openclaw/workspace-archivist/qdrant/get_memory.py \
      /home/node/.openclaw/workspace-archivist/qdrant/set_graph_link.py \
      /home/node/.openclaw/workspace-archivist/queries/run_query.py \
      /home/node/.openclaw/workspace-archivist/grooming/update_checkpoint.py
    python3 /home/node/.openclaw/workspace-archivist/qdrant/set_graph_link.py \
      --point-id smoke-test-point \
      --entity-slug ai-homebase \
      --dry-run | grep -F '\"graph\"' >/dev/null
  "
}

verify_archivist_sandbox_runtime() {
  local memgraph_host="$1"
  local qdrant_url="$2"

  if ! command -v incus >/dev/null 2>&1; then
    warn "Skipping archivist sandbox runtime checks because incus is not installed in the current shell"
    return 0
  fi

  step "Checking archivist sandbox runtime image on the Incus Docker host"
  CURRENT_COMMAND="incus exec ${INCUS_VM_NAME} -- sh -ceu 'docker run archivist sandbox validation'"
  run_checked incus exec "$INCUS_VM_NAME" -- sh -ceu "
    docker image inspect openclaw-sandbox:trixie-slim >/dev/null
    docker run --rm --entrypoint sh \
      -e MEMGRAPH_HOST='${memgraph_host}' \
      -e MEMGRAPH_PORT='7687' \
      -e MEMGRAPH_BOLT_URI='bolt://${memgraph_host}:7687' \
      -e QDRANT_URL='${qdrant_url}' \
      -e QDRANT_COLLECTION='openclaw-memory' \
      -e QDRANT_API_KEY='test-qdrant-key' \
      openclaw-sandbox:trixie-slim -ceu '
      command -v mgconsole >/dev/null
      [ \"\$MEMGRAPH_HOST\" = \"${memgraph_host}\" ]
      [ \"\$MEMGRAPH_PORT\" = \"7687\" ]
      [ \"\$MEMGRAPH_BOLT_URI\" = \"bolt://${memgraph_host}:7687\" ]
      [ \"\$QDRANT_URL\" = \"${qdrant_url}\" ]
      [ \"\$QDRANT_COLLECTION\" = \"openclaw-memory\" ]
      [ \"\$QDRANT_API_KEY\" = \"test-qdrant-key\" ]
    '
  "
}

verify_incus_hostname_resolution() {
  local host_name="$1"
  local host_listen_address="$2"
  local url_path="${3:-/health/ready}"
  local endpoint_label="${4:-$host_name}"
  local status_patterns="${5:-200|308}"

  if ! command -v incus >/dev/null 2>&1; then
    warn "Skipping Incus sandbox DNS checks because incus is not installed in the current shell"
    return 0
  fi

  step "Checking Incus VM hostname resolution for ${host_name}"
  CURRENT_COMMAND="incus exec ${INCUS_VM_NAME} -- getent hosts ${host_name}"
  run_checked incus exec "$INCUS_VM_NAME" -- sh -ceu "
    resolved_ip=\$(getent ahostsv4 '${host_name}' | awk 'NR==1 {print \$1}')
    [ -n \"\$resolved_ip\" ]
    [ \"\$resolved_ip\" = '${host_listen_address}' ]
  "

  step "Checking Docker-container reachability for ${endpoint_label}"
  CURRENT_COMMAND="incus exec ${INCUS_VM_NAME} -- docker run --rm curlimages/curl:8.12.1 -sS -o /dev/null -w '%{http_code}' http://${host_name}${url_path}"
  run_checked incus exec "$INCUS_VM_NAME" -- sh -ceu "
    status_line=\$(docker run --rm curlimages/curl:8.12.1 -sS -o /dev/null -w '%{http_code}' 'http://${host_name}${url_path}')
    [ -n \"\$status_line\" ]
    case \"\$status_line\" in
      ${status_patterns}) ;;
      *) exit 1 ;;
    esac
  "
}

gitea_api_request() {
  local method="$1"
  local endpoint="$2"
  local username="$3"
  local password="$4"
  local payload="${5:-}"
  local curl_args=(
    --silent
    --show-error
    --fail
    -u "${username}:${password}"
    -H "Host: ${GITEA_INGRESS_HOST}"
    -X "$method"
  )
  if [[ -n "$payload" ]]; then
    curl_args+=(-H 'Content-Type: application/json' -d "$payload")
  fi
  curl "${curl_args[@]}" "http://127.0.0.1${endpoint}"
}

build_gitea_repo_payload() {
  local repo_name="$1"
  python3 - "$repo_name" <<'PY'
import json
import sys

print(
    json.dumps(
        {
            "name": sys.argv[1],
            "default_branch": "main",
            "private": True,
            "auto_init": True,
            "trust_model": "default",
        }
    )
)
PY
}

build_gitea_contents_payload() {
  local commit_message="$1"
  local content_file=""
  content_file="$(mktemp /tmp/ai-homebase-gitea-content.XXXXXX)"
  cat >"$content_file"
  python3 - "$commit_message" "$content_file" <<'PY'
import base64
import json
import sys
from pathlib import Path

print(
    json.dumps(
        {
            "branch": "main",
            "message": sys.argv[1],
            "content": base64.b64encode(Path(sys.argv[2]).read_bytes()).decode(),
        }
    )
)
PY
  rm -f "$content_file"
}

verify_gitea_actions_runner() {
  if [[ "${GITEA_ACTIONS_ENABLED:-false}" != "true" ]]; then
    return 0
  fi
  if [[ ! -f "$GITEA_ACTIONS_RUNNER_CONNECTION_INFO_PATH" ]]; then
    fail "Expected Gitea Actions runner connection info at ${GITEA_ACTIONS_RUNNER_CONNECTION_INFO_PATH}"
    exit 1
  fi
  if [[ ! -s "$GITEA_ACTIONS_RUNNER_KEY_PATH" ]]; then
    fail "Expected Gitea Actions runner SSH key at ${GITEA_ACTIONS_RUNNER_KEY_PATH}"
    exit 1
  fi
  if ! command -v ssh >/dev/null 2>&1 || ! command -v ssh-keyscan >/dev/null 2>&1; then
    warn "Skipping runner-VM SSH checks because ssh/ssh-keyscan is not installed in the current shell"
    return 0
  fi

  local runner_host=""
  local runner_port=""
  local runner_user=""
  local known_hosts_file=""
  local admin_user=""
  local admin_password=""
  local runner_json=""
  local expected_runner_name="${RELEASE_NAME}-${GITEA_ACTIONS_RUNNER_VM_NAME}"

  # shellcheck disable=SC1090
  source "$GITEA_ACTIONS_RUNNER_CONNECTION_INFO_PATH"
  runner_host="${HOST_LISTEN_ADDRESS:-}"
  runner_port="${SSH_HOST_PORT:-}"
  runner_user="${REMOTE_USER:-}"
  if [[ -z "$runner_host" || -z "$runner_port" || -z "$runner_user" ]]; then
    fail "Gitea Actions runner connection info is missing HOST_LISTEN_ADDRESS, SSH_HOST_PORT, or REMOTE_USER"
    exit 1
  fi

  known_hosts_file="$(mktemp /tmp/ai-homebase-gitea-actions-runner-known-hosts.XXXXXX)"
  ssh-keyscan -p "$runner_port" "$runner_host" >"$known_hosts_file" 2>/dev/null || true
  if [[ ! -s "$known_hosts_file" ]]; then
    rm -f "$known_hosts_file"
    fail "Failed to collect SSH host keys for Gitea Actions runner VM ${runner_host}:${runner_port}"
    exit 1
  fi

  step "Checking Gitea Actions runner container on the runner VM"
  CURRENT_COMMAND="ssh ${runner_user}@${runner_host} docker inspect gitea-actions-runner"
  run_checked ssh \
    -i "$GITEA_ACTIONS_RUNNER_KEY_PATH" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=yes \
    -o "UserKnownHostsFile=${known_hosts_file}" \
    -o GlobalKnownHostsFile=/dev/null \
    -p "$runner_port" \
    "${runner_user}@${runner_host}" \
    "docker inspect gitea-actions-runner >/dev/null"
  rm -f "$known_hosts_file"

  admin_user="$(kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get secret gitea-admin-secret -o jsonpath='{.data.username}' | base64 -d)"
  admin_password="$(kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get secret gitea-admin-secret -o jsonpath='{.data.password}' | base64 -d)"

  step "Checking Gitea admin Actions runner API"
  for _ in {1..60}; do
    runner_json="$(curl --silent --show-error --fail \
      -u "${admin_user}:${admin_password}" \
      -H "Host: ${GITEA_INGRESS_HOST}" \
      "http://127.0.0.1/api/v1/admin/actions/runners" 2>/dev/null || true)"
    if [[ -n "$runner_json" ]] && python3 - "$runner_json" "$expected_runner_name" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
expected = sys.argv[2]
for runner in payload.get("runners", []):
    labels = {label.get("name") for label in runner.get("labels", [])}
    if (
        runner.get("name") == expected
        and runner.get("status") in {"online", "idle", "active"}
        and "homebase-coder" in labels
    ):
        raise SystemExit(0)
raise SystemExit(1)
PY
    then
      ok "Gitea Actions runner ${expected_runner_name} is registered"
      return 0
    fi
    sleep 2
  done

  fail "Timed out waiting for Gitea Actions runner ${expected_runner_name} to appear in the Gitea admin API."
  exit 1
}

verify_gitea_actions_smoke_workflow() {
  if [[ "${GITEA_ACTIONS_ENABLED:-false}" != "true" ]]; then
    return 0
  fi
  if [[ -z "${CODER_GITEA_USERNAME:-}" || -z "${CODER_GITEA_PASSWORD:-}" ]]; then
    warn "Skipping Gitea Actions smoke workflow because coder Gitea credentials are unavailable in bootstrap config"
    return 0
  fi

  local admin_user=""
  local admin_password=""
  local smoke_repo_name="${RELEASE_NAME}-actions-smoke"
  local smoke_repo_full_name="${CODER_GITEA_USERNAME}/${smoke_repo_name}"
  local repo_status=""
  local dockerfile_payload=""
  local workflow_payload=""
  local workflow_runs_json=""
  local workflow_state=""
  local status_body_file=""

  admin_user="$(kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get secret gitea-admin-secret -o jsonpath='{.data.username}' | base64 -d)"
  admin_password="$(kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get secret gitea-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
  status_body_file="$(mktemp /tmp/ai-homebase-gitea-actions-smoke-status.XXXXXX)"
  trap 'rm -f "$status_body_file"' RETURN

  repo_status="$(
    curl --silent --show-error \
      -o "$status_body_file" \
      -w '%{http_code}' \
      -u "${CODER_GITEA_USERNAME}:${CODER_GITEA_PASSWORD}" \
      -H "Host: ${GITEA_INGRESS_HOST}" \
      "http://127.0.0.1/api/v1/repos/${smoke_repo_full_name}"
  )"
  case "$repo_status" in
    200)
      step "Removing previous Gitea Actions smoke repo ${smoke_repo_full_name}"
      CURRENT_COMMAND="DELETE /api/v1/repos/${smoke_repo_full_name}"
      run_checked curl --silent --show-error --fail \
        -u "${CODER_GITEA_USERNAME}:${CODER_GITEA_PASSWORD}" \
        -H "Host: ${GITEA_INGRESS_HOST}" \
        -X DELETE \
        "http://127.0.0.1/api/v1/repos/${smoke_repo_full_name}"
      ;;
    404)
      ;;
    *)
      cat "$status_body_file" >&2 || true
      fail "Unexpected Gitea smoke repo lookup status for ${smoke_repo_full_name}: ${repo_status}"
      exit 1
      ;;
  esac

  step "Creating Gitea Actions smoke repo ${smoke_repo_full_name}"
  CURRENT_COMMAND="POST /api/v1/user/repos"
  run_checked gitea_api_request \
    POST \
    "/api/v1/user/repos" \
    "$CODER_GITEA_USERNAME" \
    "$CODER_GITEA_PASSWORD" \
    "$(build_gitea_repo_payload "$smoke_repo_name")"

  dockerfile_payload="$(
    cat <<'EOF' | build_gitea_contents_payload "Add Actions smoke Dockerfile"
FROM debian:trixie-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
CMD ["true"]
EOF
  )"

  step "Uploading Gitea Actions smoke Dockerfile"
  CURRENT_COMMAND="POST /api/v1/repos/${smoke_repo_full_name}/contents/Dockerfile.smoke"
  run_checked gitea_api_request \
    POST \
    "/api/v1/repos/${smoke_repo_full_name}/contents/Dockerfile.smoke" \
    "$CODER_GITEA_USERNAME" \
    "$CODER_GITEA_PASSWORD" \
    "$dockerfile_payload"

  workflow_payload="$(
    cat <<'EOF' | build_gitea_contents_payload "Add Gitea Actions smoke workflow"
name: smoke
on:
  push:
    branches:
      - main
jobs:
  smoke:
    runs-on: homebase-coder
    steps:
      - uses: actions/checkout@v4
      - name: Docker version
        run: docker version
      - name: Build smoke image
        run: docker build -f Dockerfile.smoke -t actions-smoke:smoke .
EOF
  )"

  step "Uploading Gitea Actions smoke workflow"
  CURRENT_COMMAND="POST /api/v1/repos/${smoke_repo_full_name}/contents/.gitea/workflows/smoke.yaml"
  run_checked gitea_api_request \
    POST \
    "/api/v1/repos/${smoke_repo_full_name}/contents/.gitea/workflows/smoke.yaml" \
    "$CODER_GITEA_USERNAME" \
    "$CODER_GITEA_PASSWORD" \
    "$workflow_payload"

  step "Waiting for the Gitea Actions smoke workflow to complete"
  for _ in {1..120}; do
    workflow_runs_json="$(
      curl --silent --show-error --fail \
        -u "${admin_user}:${admin_password}" \
        -H "Host: ${GITEA_INGRESS_HOST}" \
        "http://127.0.0.1/api/v1/admin/actions/runs?limit=20" 2>/dev/null || true
    )"
    if [[ -z "$workflow_runs_json" ]]; then
      sleep 2
      continue
    fi
    workflow_state="$(
      python3 - "$workflow_runs_json" "$smoke_repo_full_name" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
expected = sys.argv[2]
runs = sorted(payload.get("workflow_runs", []), key=lambda item: item.get("id", 0), reverse=True)

for run in runs:
    repo = run.get("repository") or {}
    full_name = repo.get("full_name")
    if not full_name:
        owner = repo.get("owner") or {}
        owner_name = owner.get("login") or owner.get("username") or ""
        repo_name = repo.get("name") or ""
        full_name = f"{owner_name}/{repo_name}".strip("/")
    if full_name != expected:
        continue

    status = (run.get("status") or "").lower()
    conclusion = (run.get("conclusion") or "").lower()
    if status in {"success", "skipped"} or conclusion in {"success", "skipped"}:
        print("success")
        raise SystemExit(0)
    if status in {"failure", "failed", "cancelled"} or conclusion in {"failure", "failed", "cancelled"}:
        print("failure")
        raise SystemExit(0)
    print(status or "pending")
    raise SystemExit(0)

raise SystemExit(1)
PY
    )" || true

    case "$workflow_state" in
      success)
        ok "Gitea Actions smoke workflow succeeded for ${smoke_repo_full_name}"
        rm -f "$status_body_file"
        trap - RETURN
        return 0
        ;;
      failure)
        fail "Gitea Actions smoke workflow failed for ${smoke_repo_full_name}"
        rm -f "$status_body_file"
        trap - RETURN
        exit 1
        ;;
    esac
    sleep 2
  done

  rm -f "$status_body_file"
  trap - RETURN
  fail "Timed out waiting for the Gitea Actions smoke workflow to finish for ${smoke_repo_full_name}."
  exit 1
}

NEXTCLOUD_INGRESS_HOST="$(effective_value "nextcloud.ingress.private.host")"
NEXTCLOUD_MCP_INGRESS_HOST="$(effective_value "nextcloudMcp.ingress.hosts.0.host")"
GITEA_INGRESS_HOST="$(effective_value "gitea.gitea.ingress.hosts.0.host")"
VAULTWARDEN_INGRESS_HOST="$(effective_value "vaultwarden.ingress.hosts.0.host")"
PAPERLESS_INGRESS_HOST="$(effective_value "paperlessNgx.ingress.hosts.0.host")"
OPENCLAW_INGRESS_HOST="$(effective_value "openclaw.ingress.hosts.0.host")"
REGISTRY_INGRESS_HOST="$(effective_value "registry.ingress.hosts.0.host")"
QDRANT_INGRESS_HOST="$(effective_value "qdrant.ingress.hosts.0.host")"
QDRANT_MCP_INGRESS_HOST="$(effective_value "qdrantMcp.ingress.hosts.0.host")"
MEMGRAPH_INGRESS_HOST="$(effective_value "memgraph.ingress.hosts.0.host")"
MEMGRAPH_LAB_INGRESS_HOST="$(effective_value "memgraphLab.ingress.hosts.0.host")"
HOST_LISTEN_ADDRESS_VALUE=""
if [[ -f "$INCUS_CONNECTION_INFO_PATH" ]]; then
  # shellcheck disable=SC1090
  source "$INCUS_CONNECTION_INFO_PATH"
  HOST_LISTEN_ADDRESS_VALUE="${HOST_LISTEN_ADDRESS:-}"
fi

wait_for_workload openclaw "$OPENCLAW_WAIT_TIMEOUT"
OPENCLAW_DEPLOYMENT_NAME="$(resolve_deployment_name openclaw)"
OPENCLAW_CONFIGMAP_NAME="${RELEASE_NAME}-openclaw"
verify_openclaw_mcp_bootstrap_config "$OPENCLAW_CONFIGMAP_NAME" "$OPENCLAW_DEPLOYMENT_NAME"
verify_openclaw_gateway_tooling "$OPENCLAW_DEPLOYMENT_NAME"
verify_openclaw_workspace_bootstrap "$OPENCLAW_DEPLOYMENT_NAME"

if [[ "$(is_openclaw_remote_docker_enabled)" == "true" ]]; then
  verify_openclaw_remote_docker "$OPENCLAW_DEPLOYMENT_NAME"
else
  warn "Skipping OpenClaw remote Docker checks because openclaw.remoteDocker.enabled=false in effective values"
fi

if [[ "$(is_nextcloud_enabled)" == "true" ]]; then
  wait_for_statefulset nextcloud "$NEXTCLOUD_WAIT_TIMEOUT"
  NEXTCLOUD_STATEFULSET_NAME="$(resolve_statefulset_name nextcloud)"
  verify_labeled_service nextcloud
  verify_nextcloud_bootstrap_content "$NEXTCLOUD_STATEFULSET_NAME"
  step "Checking nextcloud ingress endpoint"
  CURRENT_COMMAND="curl --silent --show-error --fail -H Host: ${NEXTCLOUD_INGRESS_HOST} http://127.0.0.1/status.php"
  wait_for_http_endpoint "${NEXTCLOUD_INGRESS_HOST}" "http://127.0.0.1/status.php" "Nextcloud"
else
  warn "Skipping Nextcloud workload/service/ingress checks because nextcloud.enabled=false in effective values"
fi

if [[ "$(is_nextcloud_mcp_enabled)" == "true" ]]; then
  wait_for_workload nextcloud-mcp "$NEXTCLOUD_MCP_WAIT_TIMEOUT"
  verify_labeled_service nextcloud-mcp
  if [[ -n "$HOST_LISTEN_ADDRESS_VALUE" ]]; then
    verify_incus_hostname_resolution "$NEXTCLOUD_MCP_INGRESS_HOST" "$HOST_LISTEN_ADDRESS_VALUE" "/health/ready" "Nextcloud MCP"
  else
    warn "Skipping Incus sandbox DNS checks because ${INCUS_CONNECTION_INFO_PATH} is missing or does not define HOST_LISTEN_ADDRESS"
  fi
  step "Checking nextcloud-mcp ingress endpoint"
  CURRENT_COMMAND="curl --silent --show-error --fail -H Host: ${NEXTCLOUD_MCP_INGRESS_HOST} http://127.0.0.1/health/ready"
  wait_for_http_endpoint "${NEXTCLOUD_MCP_INGRESS_HOST}" "http://127.0.0.1/health/ready" "Nextcloud MCP"
else
  warn "Skipping Nextcloud MCP workload/service/ingress checks because nextcloudMcp.enabled=false in effective values"
fi

if [[ "$(is_gitea_enabled)" == "true" ]]; then
  wait_for_gitea_workloads "$GITEA_WAIT_TIMEOUT"
  verify_gitea_services
  if [[ -n "$HOST_LISTEN_ADDRESS_VALUE" ]]; then
    verify_incus_hostname_resolution "$GITEA_INGRESS_HOST" "$HOST_LISTEN_ADDRESS_VALUE" "/api/v1/version" "Gitea" "200|308"
  else
    warn "Skipping Incus sandbox DNS checks for Gitea because ${INCUS_CONNECTION_INFO_PATH} is missing or does not define HOST_LISTEN_ADDRESS"
  fi
  step "Checking gitea ingress endpoint"
  CURRENT_COMMAND="curl --silent --show-error --fail -H Host: ${GITEA_INGRESS_HOST} http://127.0.0.1/api/v1/version"
  wait_for_http_endpoint "${GITEA_INGRESS_HOST}" "http://127.0.0.1/api/v1/version" "Gitea"
  verify_gitea_actions_runner
  verify_gitea_actions_smoke_workflow
else
  warn "Skipping Gitea workload/service checks because gitea.enabled=false in effective values"
fi

if [[ "$(is_registry_enabled)" == "true" ]]; then
  if [[ -n "$HOST_LISTEN_ADDRESS_VALUE" ]]; then
    verify_incus_hostname_resolution "$REGISTRY_INGRESS_HOST" "$HOST_LISTEN_ADDRESS_VALUE" "/v2/" "Registry" "200|308|401"
  else
    warn "Skipping Incus sandbox DNS checks for Registry because ${INCUS_CONNECTION_INFO_PATH} is missing or does not define HOST_LISTEN_ADDRESS"
  fi
  verify_registry_services
else
  warn "Skipping registry workload/service checks because registry.enabled=false in effective values"
fi

if [[ "$(is_vaultwarden_enabled)" == "true" ]]; then
  wait_for_workload vaultwarden "$VAULTWARDEN_WAIT_TIMEOUT"
  verify_labeled_service vaultwarden
  step "Checking vaultwarden ingress endpoint"
  CURRENT_COMMAND="curl --silent --show-error --fail -H Host: ${VAULTWARDEN_INGRESS_HOST} http://127.0.0.1/"
  wait_for_http_endpoint "${VAULTWARDEN_INGRESS_HOST}" "http://127.0.0.1/" "Vaultwarden"
else
  warn "Skipping Vaultwarden workload/service/ingress checks because vaultwarden.enabled=false in effective values"
fi

if [[ "$(is_postfix_relay_enabled)" == "true" ]]; then
  wait_for_workload postfix-relay "$POSTFIX_RELAY_WAIT_TIMEOUT"
  verify_labeled_service postfix-relay
else
  warn "Skipping Postfix relay workload/service checks because postfixRelay.enabled=false in effective values"
fi

if [[ "$(is_paperless_enabled)" == "true" ]]; then
  wait_for_statefulset paperless-ngx "$PAPERLESS_WAIT_TIMEOUT"
  verify_labeled_service paperless-ngx
  step "Checking paperless ingress endpoint"
  CURRENT_COMMAND="curl --silent --show-error --fail -H Host: ${PAPERLESS_INGRESS_HOST} http://127.0.0.1/api/health/"
  wait_for_http_endpoint "${PAPERLESS_INGRESS_HOST}" "http://127.0.0.1/api/health/" "Paperless"
else
  warn "Skipping Paperless workload/service/ingress checks because paperlessNgx.enabled=false in effective values"
fi

if [[ "$(is_qdrant_enabled)" == "true" ]]; then
  wait_for_workload qdrant "$QDRANT_WAIT_TIMEOUT"
  verify_labeled_service qdrant
  if [[ -n "$HOST_LISTEN_ADDRESS_VALUE" ]]; then
    verify_incus_hostname_resolution "$QDRANT_INGRESS_HOST" "$HOST_LISTEN_ADDRESS_VALUE" "/readyz" "Qdrant"
  else
    warn "Skipping Incus sandbox DNS checks for Qdrant because ${INCUS_CONNECTION_INFO_PATH} is missing or does not define HOST_LISTEN_ADDRESS"
  fi
  step "Checking qdrant ingress endpoint"
  CURRENT_COMMAND="curl --silent --show-error --fail -H Host: ${QDRANT_INGRESS_HOST} http://127.0.0.1/readyz"
  wait_for_http_endpoint "${QDRANT_INGRESS_HOST}" "http://127.0.0.1/readyz" "Qdrant"
else
  warn "Skipping Qdrant workload/service/ingress checks because qdrant.enabled=false in effective values"
fi

if [[ "$(is_qdrant_mcp_enabled)" == "true" ]]; then
  wait_for_workload qdrant-mcp "$QDRANT_MCP_WAIT_TIMEOUT"
  QDRANT_MCP_DEPLOYMENT_NAME="$(resolve_deployment_name qdrant-mcp)"
  verify_labeled_service qdrant-mcp
  verify_qdrant_mcp_runtime "$QDRANT_MCP_DEPLOYMENT_NAME"
  if [[ -n "$HOST_LISTEN_ADDRESS_VALUE" ]]; then
    verify_incus_hostname_resolution "$QDRANT_MCP_INGRESS_HOST" "$HOST_LISTEN_ADDRESS_VALUE" "/mcp" "Qdrant MCP" "200|308"
  else
    warn "Skipping Incus sandbox DNS checks for Qdrant MCP because ${INCUS_CONNECTION_INFO_PATH} is missing or does not define HOST_LISTEN_ADDRESS"
  fi
  step "Checking qdrant-mcp ingress endpoint"
  CURRENT_COMMAND="curl --silent --show-error --fail -H Host: ${QDRANT_MCP_INGRESS_HOST} http://127.0.0.1/mcp"
  wait_for_http_endpoint "${QDRANT_MCP_INGRESS_HOST}" "http://127.0.0.1/mcp" "Qdrant MCP"
else
  warn "Skipping Qdrant MCP workload/service/ingress checks because qdrantMcp.enabled=false in effective values"
fi

wait_for_workload memgraph "$MEMGRAPH_WAIT_TIMEOUT"
MEMGRAPH_DEPLOYMENT_NAME="$(resolve_deployment_name memgraph)"
verify_labeled_service memgraph
verify_memgraph_bootstrap "$MEMGRAPH_DEPLOYMENT_NAME"
verify_gateway_memgraph_runtime "$(resolve_deployment_name openclaw)"
if [[ "$(is_qdrant_enabled)" == "true" ]]; then
  verify_gateway_qdrant_runtime "$(resolve_deployment_name openclaw)"
fi
if [[ -n "$HOST_LISTEN_ADDRESS_VALUE" ]]; then
  if [[ "$(is_qdrant_enabled)" == "true" ]]; then
    verify_archivist_sandbox_runtime "$MEMGRAPH_INGRESS_HOST" "http://${QDRANT_INGRESS_HOST}"
  else
    verify_archivist_sandbox_runtime "$MEMGRAPH_INGRESS_HOST" ""
  fi
  verify_reviewer_sandbox_runtime
  verify_coder_sandbox_runtime "$MEMGRAPH_INGRESS_HOST"
else
  warn "Skipping sandbox runtime checks because ${INCUS_CONNECTION_INFO_PATH} is missing or does not define HOST_LISTEN_ADDRESS"
fi

wait_for_workload memgraph-lab "$MEMGRAPH_LAB_WAIT_TIMEOUT"
verify_labeled_service memgraph-lab
kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" \
  get ingress "${RELEASE_NAME}-memgraph-lab" >/dev/null

if [[ "$(is_openclaw_ingress_enabled)" == "true" ]]; then
  if [[ -n "$HOST_LISTEN_ADDRESS_VALUE" ]]; then
    verify_incus_hostname_resolution "$OPENCLAW_INGRESS_HOST" "$HOST_LISTEN_ADDRESS_VALUE" "/" "OpenClaw" "200|302|307|308"
  else
    warn "Skipping Incus sandbox DNS checks for OpenClaw because ${INCUS_CONNECTION_INFO_PATH} is missing or does not define HOST_LISTEN_ADDRESS"
  fi
  step "Checking openclaw ingress endpoint"
  CURRENT_COMMAND="curl --silent --show-error --fail -H Host: ${OPENCLAW_INGRESS_HOST} http://127.0.0.1/"
  wait_for_http_endpoint "${OPENCLAW_INGRESS_HOST}" "http://127.0.0.1/" "OpenClaw"
else
  warn "Skipping OpenClaw ingress endpoint check because openclaw.ingress.enabled=false in effective values"
fi

echo "Bootstrap smoke checks passed for profile=${PROFILE} release=${RELEASE_NAME} namespace=${NAMESPACE}"
echo "Bootstrap log: ${BOOTSTRAP_LOG_FILE}"
