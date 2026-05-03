#!/usr/bin/env bash

INGRESS_NAMESPACE="${INGRESS_NAMESPACE:-ingress-nginx}"
INGRESS_RELEASE_NAME="${INGRESS_RELEASE_NAME:-ingress-nginx}"
INGRESS_CHART_REF="${INGRESS_CHART_REF:-ingress-nginx/ingress-nginx}"
MEMGRAPH_TCP_ENABLED="${MEMGRAPH_TCP_ENABLED:-true}"
MEMGRAPH_TCP_PORT="${MEMGRAPH_TCP_PORT:-7687}"
MEMGRAPH_TCP_NAMESPACE="${MEMGRAPH_TCP_NAMESPACE:-ai-homebase}"
MEMGRAPH_TCP_RELEASE_NAME="${MEMGRAPH_TCP_RELEASE_NAME:-platform-stack}"

ensure_ingress_nginx() {
  step "Ensuring ingress-nginx Helm repo"
  run_quiet helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true
  if [[ "${BOOTSTRAP_VERBOSE:-0}" == "1" ]]; then
    run_verbose helm repo update ingress-nginx
  else
    run_quiet helm repo update ingress-nginx
  fi

  step "Installing/upgrading ingress-nginx controller"
  HELM_SET_ARGS=(
    --set controller.ingressClassResource.name=nginx
    --set controller.ingressClass=nginx
    --set controller.watchIngressWithoutClass=false
  )
  if [[ "$MEMGRAPH_TCP_ENABLED" == "true" ]]; then
    HELM_SET_ARGS+=(
      --set "tcp.${MEMGRAPH_TCP_PORT}=${MEMGRAPH_TCP_NAMESPACE}/${MEMGRAPH_TCP_RELEASE_NAME}-memgraph:${MEMGRAPH_TCP_PORT}"
    )
  fi
  run_quiet helm upgrade --install "$INGRESS_RELEASE_NAME" "$INGRESS_CHART_REF" \
    "${HELM_ARGS[@]}" \
    --namespace "$INGRESS_NAMESPACE" \
    --create-namespace \
    --hide-notes \
    "${HELM_SET_ARGS[@]}"

  step "Waiting for ingress-nginx controller readiness"
  run_quiet kubectl "${KUBECTL_ARGS[@]}" wait --namespace "$INGRESS_NAMESPACE" \
    --for=condition=Available \
    "deployment/${INGRESS_RELEASE_NAME}-controller" \
    --timeout=180s

  run_quiet kubectl "${KUBECTL_ARGS[@]}" wait --namespace "$INGRESS_NAMESPACE" \
    --for=condition=Ready \
    pods \
    -l "app.kubernetes.io/component=controller,app.kubernetes.io/instance=${INGRESS_RELEASE_NAME}" \
    --timeout=180s

  ok "Ingress controller is ready"
}
