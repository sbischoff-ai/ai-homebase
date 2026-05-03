#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/lib/logging.sh"
source "$(dirname "$0")/lib/ingress-nginx.sh"

CLUSTER_NAME="${CLUSTER_NAME:-ai-homebase-dev}"
HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_PORT="${HTTPS_PORT:-443}"
MEMGRAPH_BOLT_PORT="${MEMGRAPH_BOLT_PORT:-7687}"
ENABLE_HTTPS="${ENABLE_HTTPS:-true}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${HOME}/.kube/k3d-${CLUSTER_NAME}.yaml}"
K3S_IMAGE="${K3S_IMAGE:-rancher/k3s:v1.32.11-k3s1}"
SHARED_OPENCLAW_STATE_SOURCE="${SHARED_OPENCLAW_STATE_SOURCE:-${HOME}/.local/state/ai-homebase/openclaw-state}"
SHARED_OPENCLAW_STATE_TARGET="${SHARED_OPENCLAW_STATE_TARGET:-/var/lib/ai-homebase/openclaw-state}"
usage() {
  cat <<USAGE
Usage: $0 [options]

Create or reuse a local k3d cluster for ai-homebase and ensure ingress-nginx is ready.

Options:
  --cluster-name <name>         k3d cluster name (default: ${CLUSTER_NAME})
  --http-port <port>            Host HTTP port mapped to LB 80 (default: ${HTTP_PORT})
  --https-port <port>           Host HTTPS port mapped to LB 443 (default: ${HTTPS_PORT})
  --memgraph-bolt-port <port>   Host Memgraph Bolt port mapped to LB 7687 (default: ${MEMGRAPH_BOLT_PORT})
  --without-https               Do not map host HTTPS port 443 to the k3s load balancer
  --kubeconfig <path>           Write/use dedicated kubeconfig path (default: ${KUBECONFIG_PATH})
  --k3s-image <image>           k3s image to use for the cluster (default: ${K3S_IMAGE})
  --shared-openclaw-state-source <path>
                                Host path bind-mounted into the k3d nodes for shared OpenClaw state (default: ${SHARED_OPENCLAW_STATE_SOURCE})
  --shared-openclaw-state-target <path>
                                Node path used for the shared OpenClaw state bind mount (default: ${SHARED_OPENCLAW_STATE_TARGET})
  --verbose                     Stream full command output
  -h, --help                    Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster-name) CLUSTER_NAME="$2"; shift 2 ;;
    --http-port) HTTP_PORT="$2"; shift 2 ;;
    --https-port) HTTPS_PORT="$2"; shift 2 ;;
    --memgraph-bolt-port) MEMGRAPH_BOLT_PORT="$2"; shift 2 ;;
    --without-https) ENABLE_HTTPS="false"; shift ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --k3s-image) K3S_IMAGE="$2"; shift 2 ;;
    --shared-openclaw-state-source) SHARED_OPENCLAW_STATE_SOURCE="$2"; shift 2 ;;
    --shared-openclaw-state-target) SHARED_OPENCLAW_STATE_TARGET="$2"; shift 2 ;;
    --verbose) BOOTSTRAP_VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

bootstrap_init_logging
trap 'fail "k3d bootstrap failed. Log: ${BOOTSTRAP_LOG_FILE}"' ERR

for cmd in k3d kubectl helm docker; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Missing required dependency: $cmd"
    exit 1
  fi
done

K3D_CONTEXT="k3d-${CLUSTER_NAME}"
KUBECTL_ARGS=(--kubeconfig "$KUBECONFIG_PATH")
HELM_ARGS=(--kubeconfig "$KUBECONFIG_PATH")

run_quiet mkdir -p "$(dirname "$KUBECONFIG_PATH")"
run_quiet mkdir -p "$SHARED_OPENCLAW_STATE_SOURCE"
export KUBECONFIG="$KUBECONFIG_PATH"

run_k3d_concise() {
  if [[ "${BOOTSTRAP_VERBOSE:-0}" == "1" ]]; then
    run_verbose "$@"
  else
    local cmd_output
    local status

    if cmd_output="$("$@" 2>&1)"; then
      status=0
    else
      status=$?
    fi

    if [[ -n "$cmd_output" ]]; then
      printf "%s\n" "$cmd_output" >>"$BOOTSTRAP_LOG_FILE"
      if [[ $status -ne 0 ]]; then
        printf "%s\n" "$cmd_output" >&2
      fi
    fi

    return $status
  fi
}

cluster_has_shared_openclaw_state_mount() {
  local node_name mount_summary mount_source

  node_name="k3d-${CLUSTER_NAME}-server-0"
  if ! mount_summary="$(docker inspect "$node_name" --format '{{range .Mounts}}{{println .Source "|" .Destination}}{{end}}' 2>/dev/null)"; then
    warn "Unable to inspect ${node_name}; recreating the cluster so the shared OpenClaw state bind mount is present."
    return 1
  fi

  mount_source="$(printf '%s\n' "$mount_summary" | awk -F'|' -v target="$SHARED_OPENCLAW_STATE_TARGET" '
    {
      source=$1
      destination=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", source)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", destination)
      if (destination == target) {
        print source
        exit
      }
    }
  ')"
  if [[ -z "$mount_source" ]]; then
    warn "Existing k3d cluster ${CLUSTER_NAME} is missing the shared OpenClaw state mount at ${SHARED_OPENCLAW_STATE_TARGET}; recreating it."
    return 1
  fi

  if [[ "$mount_source" != "$SHARED_OPENCLAW_STATE_SOURCE" ]]; then
    warn "Existing k3d cluster ${CLUSTER_NAME} mounts ${SHARED_OPENCLAW_STATE_TARGET} from ${mount_source}, but this bootstrap expects ${SHARED_OPENCLAW_STATE_SOURCE}; recreating it."
    return 1
  fi

  return 0
}

cluster_has_memgraph_bolt_port_mapping() {
  local lb_name port_summary

  lb_name="k3d-${CLUSTER_NAME}-serverlb"
  if ! port_summary="$(docker inspect "$lb_name" --format '{{json .NetworkSettings.Ports}}' 2>/dev/null)"; then
    warn "Unable to inspect ${lb_name}; recreating the cluster so the Memgraph Bolt port mapping is present."
    return 1
  fi

  if ! printf '%s' "$port_summary" | grep -F "\"7687/tcp\"" >/dev/null; then
    warn "Existing k3d cluster ${CLUSTER_NAME} is missing the Memgraph Bolt load balancer mapping at ${MEMGRAPH_BOLT_PORT}:7687; recreating it."
    return 1
  fi

  return 0
}

probe_k3d_cluster() {
  local cmd_output
  local status

  if cmd_output="$(k3d kubeconfig get "$CLUSTER_NAME" 2>&1)"; then
    status=0
  else
    status=$?
  fi

  if [[ -n "$cmd_output" ]]; then
    printf "%s\n" "$cmd_output" >>"$BOOTSTRAP_LOG_FILE"
  fi

  if [[ $status -eq 0 ]]; then
    return 0
  fi

  if printf '%s' "$cmd_output" | tr '[:upper:]' '[:lower:]' | grep -Eq '(cluster.*not found|no such cluster|does not exist|nodes don.t exist|no nodes found)'; then
    return 1
  fi

  if [[ -n "$cmd_output" ]]; then
    printf "%s\n" "$cmd_output" >&2
  fi

  return 2
}

if probe_k3d_cluster; then
  step "Reusing existing k3d cluster ${CLUSTER_NAME}"
  if cluster_has_shared_openclaw_state_mount && cluster_has_memgraph_bolt_port_mapping; then
    ok "Existing cluster has the shared OpenClaw state mount and Memgraph Bolt mapping"
  else
    step "Recreating incompatible k3d cluster ${CLUSTER_NAME}"
    run_k3d_concise k3d cluster delete "$CLUSTER_NAME"
    echo "ℹ Recreating cluster ${CLUSTER_NAME} with the expected shared OpenClaw state mount."
    CREATE_ARGS=(
      --wait
      --image "$K3S_IMAGE"
      -p "${HTTP_PORT}:80@loadbalancer"
      -p "${MEMGRAPH_BOLT_PORT}:7687@loadbalancer"
      --volume "/lib/modules:/lib/modules@all"
      --volume "${SHARED_OPENCLAW_STATE_SOURCE}:${SHARED_OPENCLAW_STATE_TARGET}@all"
      --k3s-arg "--disable=traefik@server:*"
    )

    if [[ "$ENABLE_HTTPS" == "true" ]]; then
      CREATE_ARGS+=( -p "${HTTPS_PORT}:443@loadbalancer" )
    fi

    step "Creating k3d cluster ${CLUSTER_NAME}"
    run_k3d_concise k3d cluster create "$CLUSTER_NAME" "${CREATE_ARGS[@]}"
  fi
else
  cluster_probe_status=$?

  if [[ $cluster_probe_status -eq 1 ]]; then
    echo "ℹ Cluster not found; creating new cluster ${CLUSTER_NAME}."
    CREATE_ARGS=(
      --wait
      --image "$K3S_IMAGE"
      -p "${HTTP_PORT}:80@loadbalancer"
      -p "${MEMGRAPH_BOLT_PORT}:7687@loadbalancer"
      --volume "/lib/modules:/lib/modules@all"
      --volume "${SHARED_OPENCLAW_STATE_SOURCE}:${SHARED_OPENCLAW_STATE_TARGET}@all"
      --k3s-arg "--disable=traefik@server:*"
    )

    if [[ "$ENABLE_HTTPS" == "true" ]]; then
      CREATE_ARGS+=( -p "${HTTPS_PORT}:443@loadbalancer" )
    fi


    step "Creating k3d cluster ${CLUSTER_NAME}"
    run_k3d_concise k3d cluster create "$CLUSTER_NAME" "${CREATE_ARGS[@]}"
  else
    fail "Failed to probe cluster ${CLUSTER_NAME}; see output above."
    exit 1
  fi
fi

step "Writing dedicated kubeconfig to ${KUBECONFIG_PATH}"
run_k3d_concise bash -c 'k3d kubeconfig get "$1" > "$2"' _ "$CLUSTER_NAME" "$KUBECONFIG_PATH"
if grep -q 'server: https://0\.0\.0\.0:' "$KUBECONFIG_PATH"; then
  run_quiet sed -i 's#server: https://0\.0\.0\.0:#server: https://127.0.0.1:#' "$KUBECONFIG_PATH"
fi
ok "Kubeconfig written to ${KUBECONFIG_PATH}"

run_quiet kubectl "${KUBECTL_ARGS[@]}" config use-context "$K3D_CONTEXT"
CURRENT_CONTEXT="$(kubectl "${KUBECTL_ARGS[@]}" config current-context)"
if [[ "$CURRENT_CONTEXT" != "$K3D_CONTEXT" ]]; then
  fail "Failed to switch kubectl context to ${K3D_CONTEXT} (current: ${CURRENT_CONTEXT})"
  exit 1
fi
ok "kubectl context is ${CURRENT_CONTEXT}"

step "Running cluster warm-up checks"
run_quiet kubectl "${KUBECTL_ARGS[@]}" wait --for=condition=Ready node --all --timeout=180s

if run_quiet kubectl "${KUBECTL_ARGS[@]}" get apiservice v1beta1.metrics.k8s.io; then
  step "Waiting for APIService v1beta1.metrics.k8s.io to become Available"
  metrics_deadline=$((SECONDS + 120))
  metrics_ready="false"

  while [[ $SECONDS -lt $metrics_deadline ]]; do
    if kubectl "${KUBECTL_ARGS[@]}" get apiservice v1beta1.metrics.k8s.io \
      -o jsonpath='{range .status.conditions[?(@.type=="Available")]}{.status}{end}' 2>/dev/null | grep -q '^True$'; then
      metrics_ready="true"
      break
    fi
    sleep 5
  done

  if [[ "$metrics_ready" != "true" ]]; then
    warn "APIService v1beta1.metrics.k8s.io did not become Available within 120s; continuing bootstrap"
  fi
fi

ensure_ingress_nginx
echo "k3d cluster ${CLUSTER_NAME} is ready with ingress-nginx"
echo "k3s image: ${K3S_IMAGE}"
echo "Kubeconfig written to: ${KUBECONFIG_PATH}"
echo "Bootstrap log: ${BOOTSTRAP_LOG_FILE}"
echo "KUBECONFIG exported for this run: ${KUBECONFIG}"
