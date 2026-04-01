#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/lib/logging.sh"

RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
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
SKIP_INSTALL=0
OPENCLAW_WAIT_TIMEOUT="${OPENCLAW_WAIT_TIMEOUT:-600s}"
NEXTCLOUD_WAIT_TIMEOUT="${NEXTCLOUD_WAIT_TIMEOUT:-1200s}"
NEXTCLOUD_MCP_WAIT_TIMEOUT="${NEXTCLOUD_MCP_WAIT_TIMEOUT:-900s}"
GITEA_WAIT_TIMEOUT="${GITEA_WAIT_TIMEOUT:-1200s}"
VAULTWARDEN_WAIT_TIMEOUT="${VAULTWARDEN_WAIT_TIMEOUT:-900s}"
POSTFIX_RELAY_WAIT_TIMEOUT="${POSTFIX_RELAY_WAIT_TIMEOUT:-600s}"
PAPERLESS_WAIT_TIMEOUT="${PAPERLESS_WAIT_TIMEOUT:-1200s}"
QDRANT_WAIT_TIMEOUT="${QDRANT_WAIT_TIMEOUT:-900s}"
QDRANT_MCP_WAIT_TIMEOUT="${QDRANT_MCP_WAIT_TIMEOUT:-1200s}"
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
Usage: $0 [options]

Deploy the k3d profile and run local smoke checks.

Options:
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
  --skip-install              Skip the shared bootstrap/install phase and run smoke checks only
  Env timeouts                OPENCLAW_WAIT_TIMEOUT=${OPENCLAW_WAIT_TIMEOUT}, NEXTCLOUD_WAIT_TIMEOUT=${NEXTCLOUD_WAIT_TIMEOUT}, GITEA_WAIT_TIMEOUT=${GITEA_WAIT_TIMEOUT}, VAULTWARDEN_WAIT_TIMEOUT=${VAULTWARDEN_WAIT_TIMEOUT}, POSTFIX_RELAY_WAIT_TIMEOUT=${POSTFIX_RELAY_WAIT_TIMEOUT}, PAPERLESS_WAIT_TIMEOUT=${PAPERLESS_WAIT_TIMEOUT}
  Ingress retry tuning        INGRESS_ENDPOINT_RETRIES=${INGRESS_ENDPOINT_RETRIES}, INGRESS_ENDPOINT_RETRY_DELAY_SECONDS=${INGRESS_ENDPOINT_RETRY_DELAY_SECONDS}
  --verbose                   Stream full command output
  -h, --help                  Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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
    --skip-install) SKIP_INSTALL=1; shift ;;
    --verbose) BOOTSTRAP_VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$KUBECONFIG_PATH" ]]; then
  KUBECONFIG_PATH="$(normalize_kubeconfig_path "$RAW_KUBECONFIG")"
fi

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
  echo "   ./scripts/test-local-k3d.sh --release-name ${RELEASE_NAME} --namespace ${NAMESPACE} --verbose" >&2
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

  step "Checking OpenClaw gateway tooling for watchdog/session-logs"
  CURRENT_COMMAND="kubectl exec deployment/${deployment_name} -- sh -ceu 'command -v jq && command -v rg'"
  run_checked kubectl "${KUBECTL_KUBECONFIG_ARGS[@]}" "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" exec "deployment/${deployment_name}" -- sh -ceu "
    command -v jq >/dev/null
    command -v rg >/dev/null
  "
}

verify_openclaw_mcp_bootstrap_config() {
  local configmap_name="$1"
  local deployment_name="$2"
  local openclaw_json=""
  local cron_jobs_json=""

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

  if [[ "$openclaw_json" != *'registry.localtest.me/openclaw/openclaw-sandbox:bookworm-slim'* ]]; then
    fail "OpenClaw bootstrap config in ConfigMap/${configmap_name} is not using the canonical registry-backed default sandbox image"
    exit 1
  fi

  if [[ "$openclaw_json" != *'registry.localtest.me/openclaw/openclaw-sandbox-coder:bookworm-slim'* ]]; then
    fail "OpenClaw bootstrap config in ConfigMap/${configmap_name} is not using the canonical registry-backed coder sandbox image"
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
    "Watchdog heartbeat",
    "Watchdog platform sweep",
    "Archivist nightly grooming",
    "Watchdog daily digest",
}
if not expected.issubset(names):
    missing = ", ".join(sorted(expected - names))
    raise SystemExit(f"missing cron jobs: {missing}")
PY
  then
    fail "OpenClaw gateway is missing one or more seeded cron jobs"
    exit 1
  fi
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
  CURRENT_COMMAND="incus exec ${INCUS_VM_NAME} -- docker run --rm curlimages/curl:8.12.1 -sSI http://${host_name}${url_path}"
  run_checked incus exec "$INCUS_VM_NAME" -- sh -ceu "
    status_line=\$(docker run --rm curlimages/curl:8.12.1 -sSI 'http://${host_name}${url_path}' | awk 'NR==1 {print \$2}')
    [ -n \"\$status_line\" ]
    case \"\$status_line\" in
      ${status_patterns}) ;;
      *) exit 1 ;;
    esac
  "
}

if [[ "$SKIP_INSTALL" -eq 0 ]]; then
  BOOTSTRAP_STACK_CMD=(
    ./scripts/bootstrap-stack.sh
    --profile k3d
    --bootstrap-config "$BOOTSTRAP_CONFIG_PATH"
    --release-name "$RELEASE_NAME"
    --namespace "$NAMESPACE"
  )
  if [[ -n "$KUBECONFIG_PATH" ]]; then
    BOOTSTRAP_STACK_CMD+=(--kubeconfig "$KUBECONFIG_PATH")
  fi
  if [[ -n "$KUBE_CONTEXT" ]]; then
    BOOTSTRAP_STACK_CMD+=(--kube-context "$KUBE_CONTEXT")
  fi
  if [[ -n "$REMOTE_DOCKER_SECRET_NAME" ]]; then
    BOOTSTRAP_STACK_CMD+=(--remote-docker-secret "$REMOTE_DOCKER_SECRET_NAME")
  fi
  if [[ -n "$REMOTE_DOCKER_HOST" ]]; then
    BOOTSTRAP_STACK_CMD+=(--remote-docker-host "$REMOTE_DOCKER_HOST")
  fi
  if [[ -n "$REMOTE_DOCKER_PORT" ]]; then
    BOOTSTRAP_STACK_CMD+=(--remote-docker-port "$REMOTE_DOCKER_PORT")
  fi
  if [[ -n "$REMOTE_DOCKER_KEY_PATH" ]]; then
    BOOTSTRAP_STACK_CMD+=(--remote-docker-key "$REMOTE_DOCKER_KEY_PATH")
  fi
  for values_file in "${VALUES_FILES[@]}"; do
    BOOTSTRAP_STACK_CMD+=(--values-file "$values_file")
  done
  if [[ "${BOOTSTRAP_VERBOSE:-0}" == "1" ]]; then
    BOOTSTRAP_STACK_CMD+=(--verbose)
  fi

  step "Running shared bootstrap/install flow for k3d"
  run_checked "${BOOTSTRAP_STACK_CMD[@]}"
fi

NEXTCLOUD_INGRESS_HOST="$(effective_value "nextcloud.ingress.private.host")"
NEXTCLOUD_MCP_INGRESS_HOST="$(effective_value "nextcloudMcp.ingress.hosts.0.host")"
VAULTWARDEN_INGRESS_HOST="$(effective_value "vaultwarden.ingress.hosts.0.host")"
PAPERLESS_INGRESS_HOST="$(effective_value "paperlessNgx.ingress.hosts.0.host")"
OPENCLAW_INGRESS_HOST="$(effective_value "openclaw.ingress.hosts.0.host")"
REGISTRY_INGRESS_HOST="$(effective_value "registry.ingress.hosts.0.host")"
QDRANT_INGRESS_HOST="$(effective_value "qdrant.ingress.hosts.0.host")"
QDRANT_MCP_INGRESS_HOST="$(effective_value "qdrantMcp.ingress.hosts.0.host")"
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

if [[ "$(is_openclaw_remote_docker_enabled)" == "true" ]]; then
  verify_openclaw_remote_docker "$OPENCLAW_DEPLOYMENT_NAME"
else
  warn "Skipping OpenClaw remote Docker checks because openclaw.remoteDocker.enabled=false in effective values"
fi

if [[ "$(is_nextcloud_enabled)" == "true" ]]; then
  wait_for_statefulset nextcloud "$NEXTCLOUD_WAIT_TIMEOUT"
  verify_labeled_service nextcloud
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
  step "Checking qdrant ingress endpoint"
  CURRENT_COMMAND="curl --silent --show-error --fail -H Host: ${QDRANT_INGRESS_HOST} http://127.0.0.1/readyz"
  wait_for_http_endpoint "${QDRANT_INGRESS_HOST}" "http://127.0.0.1/readyz" "Qdrant"
else
  warn "Skipping Qdrant workload/service/ingress checks because qdrant.enabled=false in effective values"
fi

if [[ "$(is_qdrant_mcp_enabled)" == "true" ]]; then
  wait_for_workload qdrant-mcp "$QDRANT_MCP_WAIT_TIMEOUT"
  verify_labeled_service qdrant-mcp
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

echo "Local k3d smoke checks passed for release=${RELEASE_NAME} namespace=${NAMESPACE}"
echo "Bootstrap log: ${BOOTSTRAP_LOG_FILE}"
