#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-ai-homebase-dev}"
HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_PORT="${HTTPS_PORT:-443}"
ENABLE_HTTPS="${ENABLE_HTTPS:-true}"
INGRESS_NAMESPACE="${INGRESS_NAMESPACE:-ingress-nginx}"
INGRESS_RELEASE_NAME="${INGRESS_RELEASE_NAME:-ingress-nginx}"
INGRESS_CHART_REF="${INGRESS_CHART_REF:-ingress-nginx/ingress-nginx}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${HOME}/.kube/k3d-${CLUSTER_NAME}.yaml}"

usage() {
  cat <<USAGE
Usage: $0 [options]

Create or reuse a local k3d cluster for ai-homebase and ensure ingress-nginx is ready.

Options:
  --cluster-name <name>         k3d cluster name (default: ${CLUSTER_NAME})
  --http-port <port>            Host HTTP port mapped to LB 80 (default: ${HTTP_PORT})
  --https-port <port>           Host HTTPS port mapped to LB 443 (default: ${HTTPS_PORT})
  --without-https               Do not map host HTTPS port 443 to the k3s load balancer
  --kubeconfig <path>           Write/use dedicated kubeconfig path (default: ${KUBECONFIG_PATH})
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
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

for cmd in k3d kubectl helm; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required dependency: $cmd" >&2
    exit 1
  fi
done

K3D_CONTEXT="k3d-${CLUSTER_NAME}"
KUBECTL_ARGS=(--kubeconfig "$KUBECONFIG_PATH")
HELM_ARGS=(--kubeconfig "$KUBECONFIG_PATH")

mkdir -p "$(dirname "$KUBECONFIG_PATH")"

if k3d kubeconfig get "$CLUSTER_NAME" >/dev/null 2>&1; then
  echo "Cluster ${CLUSTER_NAME} already exists; reusing it"
else
  CREATE_ARGS=(
    --wait
    -p "${HTTP_PORT}:80@loadbalancer"
  )

  if [[ "$ENABLE_HTTPS" == "true" ]]; then
    CREATE_ARGS+=( -p "${HTTPS_PORT}:443@loadbalancer" )
  fi

  echo "Creating k3d cluster ${CLUSTER_NAME}"
  k3d cluster create "$CLUSTER_NAME" "${CREATE_ARGS[@]}"
fi

echo "Writing dedicated kubeconfig to ${KUBECONFIG_PATH}"
k3d kubeconfig get "$CLUSTER_NAME" > "$KUBECONFIG_PATH"

kubectl "${KUBECTL_ARGS[@]}" config use-context "$K3D_CONTEXT" >/dev/null
CURRENT_CONTEXT="$(kubectl "${KUBECTL_ARGS[@]}" config current-context)"
if [[ "$CURRENT_CONTEXT" != "$K3D_CONTEXT" ]]; then
  echo "Failed to switch kubectl context to ${K3D_CONTEXT} (current: ${CURRENT_CONTEXT})" >&2
  exit 1
fi
echo "kubectl context is ${CURRENT_CONTEXT}"

echo "Running cluster warm-up checks to prevent transient API discovery errors during initial Helm install"
echo "Waiting for cluster nodes to report Ready"
kubectl "${KUBECTL_ARGS[@]}" wait --for=condition=Ready node --all --timeout=180s

if kubectl "${KUBECTL_ARGS[@]}" get apiservice v1beta1.metrics.k8s.io >/dev/null 2>&1; then
  echo "Waiting for APIService v1beta1.metrics.k8s.io to become Available"
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
    echo "Warning: APIService v1beta1.metrics.k8s.io did not become Available within 120s; continuing bootstrap" >&2
  fi
fi

echo "Ensuring ingress-nginx Helm repo"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
helm repo update ingress-nginx >/dev/null

echo "Installing/upgrading ingress-nginx controller"
helm upgrade --install "$INGRESS_RELEASE_NAME" "$INGRESS_CHART_REF" \
  "${HELM_ARGS[@]}" \
  --namespace "$INGRESS_NAMESPACE" \
  --create-namespace \
  --set controller.ingressClassResource.name=nginx \
  --set controller.ingressClass=nginx \
  --set controller.watchIngressWithoutClass=false

echo "Waiting for ingress-nginx controller readiness"
kubectl "${KUBECTL_ARGS[@]}" wait --namespace "$INGRESS_NAMESPACE" \
  --for=condition=Available \
  deployment/${INGRESS_RELEASE_NAME}-controller \
  --timeout=180s

kubectl "${KUBECTL_ARGS[@]}" wait --namespace "$INGRESS_NAMESPACE" \
  --for=condition=Ready \
  pods \
  -l app.kubernetes.io/component=controller,app.kubernetes.io/instance=${INGRESS_RELEASE_NAME} \
  --timeout=180s

echo "k3d cluster ${CLUSTER_NAME} is ready with ingress-nginx"
echo "Kubeconfig written to: ${KUBECONFIG_PATH}"
echo "Use it with: export KUBECONFIG=${KUBECONFIG_PATH}"
