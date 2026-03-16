#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/lib/logging.sh"

CLUSTER_NAME="${CLUSTER_NAME:-ai-homebase-dev}"
HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_PORT="${HTTPS_PORT:-443}"
ENABLE_HTTPS="${ENABLE_HTTPS:-true}"
INGRESS_NAMESPACE="${INGRESS_NAMESPACE:-ingress-nginx}"
INGRESS_RELEASE_NAME="${INGRESS_RELEASE_NAME:-ingress-nginx}"
INGRESS_CHART_REF="${INGRESS_CHART_REF:-ingress-nginx/ingress-nginx}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${HOME}/.kube/k3d-${CLUSTER_NAME}.yaml}"
EXTRA_CREATE_ARGS=()

append_create_arg() {
  local raw_arg="$1"

  if [[ "$raw_arg" =~ [[:space:]] ]]; then
    local split_args=()
    # Support callers passing a combined flag+value string, e.g.
    # --k3d-create-arg "--volume /lib/modules:/lib/modules@all".
    # shellcheck disable=SC2206
    split_args=($raw_arg)
    EXTRA_CREATE_ARGS+=("${split_args[@]}")
    return
  fi

  EXTRA_CREATE_ARGS+=("$raw_arg")
}

usage() {
  cat <<USAGE
Usage: $0 [options]

Create or reuse a local k3d cluster for ai-homebase and ensure ingress-nginx is ready.

Options:
  --cluster-name <name>         k3d cluster name (default: ${CLUSTER_NAME})
  --http-port <port>            Host HTTP port mapped to LB 80 (default: ${HTTP_PORT})
  --https-port <port>           Host HTTPS port mapped to LB 443 (default: ${HTTPS_PORT})
                                Also maps wg-easy ports 51820/udp and 51821/tcp from server node
  --without-https               Do not map host HTTPS port 443 to the k3s load balancer
  --kubeconfig <path>           Write/use dedicated kubeconfig path (default: ${KUBECONFIG_PATH})
  --k3d-create-arg <arg>        Additional raw arg forwarded to 'k3d cluster create'
                                (repeatable, for advanced runtime/security flags;
                                 supports either split args or a quoted flag+value pair)
  --verbose                     Stream full command output
  -h, --help                    Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster-name) CLUSTER_NAME="$2"; shift 2 ;;
    --http-port) HTTP_PORT="$2"; shift 2 ;;
    --https-port) HTTPS_PORT="$2"; shift 2 ;;
    --without-https) ENABLE_HTTPS="false"; shift ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --k3d-create-arg) append_create_arg "$2"; shift 2 ;;
    --verbose) BOOTSTRAP_VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

bootstrap_init_logging
trap 'fail "k3d bootstrap failed. Log: ${BOOTSTRAP_LOG_FILE}"' ERR

for cmd in k3d kubectl helm; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Missing required dependency: $cmd"
    exit 1
  fi
done

K3D_CONTEXT="k3d-${CLUSTER_NAME}"
KUBECTL_ARGS=(--kubeconfig "$KUBECONFIG_PATH")
HELM_ARGS=(--kubeconfig "$KUBECONFIG_PATH")

run_quiet mkdir -p "$(dirname "$KUBECONFIG_PATH")"

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
else
  cluster_probe_status=$?

  if [[ $cluster_probe_status -eq 1 ]]; then
    echo "ℹ Cluster not found; creating new cluster ${CLUSTER_NAME}."
    CREATE_ARGS=(
      --wait
      -p "${HTTP_PORT}:80@loadbalancer"
      -p "51820:51820/udp@server:0"
      -p "51821:51821@server:0"
    )

    if [[ "$ENABLE_HTTPS" == "true" ]]; then
      CREATE_ARGS+=( -p "${HTTPS_PORT}:443@loadbalancer" )
    fi

    if [[ ${#EXTRA_CREATE_ARGS[@]} -gt 0 ]]; then
      CREATE_ARGS+=( "${EXTRA_CREATE_ARGS[@]}" )
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

step "Ensuring ingress-nginx Helm repo"
run_quiet helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true
if [[ "${BOOTSTRAP_VERBOSE:-0}" == "1" ]]; then
  run_verbose helm repo update ingress-nginx
else
  run_quiet helm repo update ingress-nginx
fi

step "Installing/upgrading ingress-nginx controller"
run_quiet helm upgrade --install "$INGRESS_RELEASE_NAME" "$INGRESS_CHART_REF" \
  "${HELM_ARGS[@]}" \
  --namespace "$INGRESS_NAMESPACE" \
  --create-namespace \
  --hide-notes \
  --set controller.ingressClassResource.name=nginx \
  --set controller.ingressClass=nginx \
  --set controller.watchIngressWithoutClass=false

step "Waiting for ingress-nginx controller readiness"
run_quiet kubectl "${KUBECTL_ARGS[@]}" wait --namespace "$INGRESS_NAMESPACE" \
  --for=condition=Available \
  deployment/${INGRESS_RELEASE_NAME}-controller \
  --timeout=180s

run_quiet kubectl "${KUBECTL_ARGS[@]}" wait --namespace "$INGRESS_NAMESPACE" \
  --for=condition=Ready \
  pods \
  -l app.kubernetes.io/component=controller,app.kubernetes.io/instance=${INGRESS_RELEASE_NAME} \
  --timeout=180s

ok "Ingress controller is ready"
echo "k3d cluster ${CLUSTER_NAME} is ready with ingress-nginx"
echo "Kubeconfig written to: ${KUBECONFIG_PATH}"
echo "Bootstrap log: ${BOOTSTRAP_LOG_FILE}"
echo "Use it with: export KUBECONFIG=${KUBECONFIG_PATH}"
