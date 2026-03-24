#!/usr/bin/env bash
set -euo pipefail

RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
PROFILE="${PROFILE:-}"
VALUES_FILES=()
BOOTSTRAP_CONFIG_PATH="${BOOTSTRAP_CONFIG_PATH:-}"
KUBE_CONTEXT="${KUBE_CONTEXT:-}"
SET_ARGS=()
BOOTSTRAP_VALUES_FILE=""
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${KUBECONFIG:-}}"
CERT_MANAGER_CRD_WAIT_TIMEOUT="${CERT_MANAGER_CRD_WAIT_TIMEOUT:-180s}"
CERT_MANAGER_DEPLOYMENT_WAIT_TIMEOUT="${CERT_MANAGER_DEPLOYMENT_WAIT_TIMEOUT:-180s}"
CERT_MANAGER_CRDS=(
  certificates.cert-manager.io
  certificaterequests.cert-manager.io
  challenges.acme.cert-manager.io
  clusterissuers.cert-manager.io
  issuers.cert-manager.io
  orders.acme.cert-manager.io
)
CERT_MANAGER_DEPLOYMENTS=(
  cert-manager
  cert-manager-cainjector
  cert-manager-webhook
)

normalize_service_key() {
  case "$1" in
    openclaw|nextcloud|gitea|vaultwarden) echo "$1" ;;
    postfix-relay|postfixRelay) echo "postfixRelay" ;;
    argo-cd|argocd|argoCd) echo "argoCd" ;;
    paperless-ngx|paperlessNgx) echo "paperlessNgx" ;;
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
  --values-file <path>        Extra values file path layered after the profile defaults (repeatable)
  --bootstrap-config <path>   Optional bootstrap config file used to render an extra values layer
  --enable-service <name>     Enable a service (repeatable)
  --disable-service <name>    Disable a service (repeatable)
  --kube-context <context>    Optional kube context
  --kubeconfig <path>         Optional kubeconfig path
  -h, --help                  Show this help message

Supported services: openclaw, nextcloud, gitea, argo-cd, vaultwarden, postfix-relay, paperless-ngx
USAGE
}

helm_upgrade_install() {
  helm upgrade --install "$RELEASE_NAME" charts/platform-stack \
    "${HELM_CONTEXT_ARGS[@]}" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    "${VALUES_ARGS[@]}" \
    "$@" \
    "${SET_ARGS[@]}"
}

cert_manager_install_enabled() {
  helm template "$RELEASE_NAME" charts/platform-stack \
    "${HELM_CONTEXT_ARGS[@]}" \
    --namespace "$NAMESPACE" \
    "${VALUES_ARGS[@]}" \
    "${SET_ARGS[@]}" \
    | grep -q 'helm.sh/chart: cert-manager'
}

wait_for_cert_manager_crds() {
  local crd
  for crd in "${CERT_MANAGER_CRDS[@]}"; do
    echo "Waiting for cert-manager CRD ${crd}"
    kubectl "${KUBECTL_CONTEXT_ARGS[@]}" wait --for=create "crd/${crd}" --timeout "${CERT_MANAGER_CRD_WAIT_TIMEOUT}"
  done
}

wait_for_cert_manager_deployments() {
  local deployment
  for deployment in "${CERT_MANAGER_DEPLOYMENTS[@]}"; do
    echo "Waiting for cert-manager deployment ${deployment} in namespace ${NAMESPACE}"
    kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" rollout status "deployment/${deployment}" --timeout "${CERT_MANAGER_DEPLOYMENT_WAIT_TIMEOUT}"
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --release-name) RELEASE_NAME="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --values-file) VALUES_FILES+=("$2"); shift 2 ;;
    --bootstrap-config) BOOTSTRAP_CONFIG_PATH="$2"; shift 2 ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
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

PROFILE_VALUES_FILES=()
mapfile -t PROFILE_VALUES_FILES < <(default_values_files_for_profile "$PROFILE") || {
  echo "Unsupported profile: $PROFILE (supported: k3d, k3s)" >&2
  exit 1
}
VALUES_FILES=("${PROFILE_VALUES_FILES[@]}" "${VALUES_FILES[@]}")

if [[ -z "$BOOTSTRAP_CONFIG_PATH" && -f bootstrap.local.toml ]]; then
  BOOTSTRAP_CONFIG_PATH="bootstrap.local.toml"
fi

HELM_CONTEXT_ARGS=()
KUBECTL_CONTEXT_ARGS=()
if [[ -n "$KUBE_CONTEXT" ]]; then
  HELM_CONTEXT_ARGS=(--kube-context "$KUBE_CONTEXT")
  KUBECTL_CONTEXT_ARGS=(--context "$KUBE_CONTEXT")
fi

if [[ -n "$KUBECONFIG_PATH" ]]; then
  HELM_CONTEXT_ARGS+=(--kubeconfig "$KUBECONFIG_PATH")
  KUBECTL_CONTEXT_ARGS+=(--kubeconfig "$KUBECONFIG_PATH")
fi

VALUES_ARGS=()
for values_file in "${VALUES_FILES[@]}"; do
  VALUES_ARGS+=(--values "$values_file")
done

if [[ -n "$BOOTSTRAP_CONFIG_PATH" ]]; then
  BOOTSTRAP_VALUES_FILE="$(mktemp /tmp/ai-homebase-bootstrap-install-values.XXXXXX.yaml)"
  trap 'rm -f "$BOOTSTRAP_VALUES_FILE"' EXIT
  python3 ./scripts/bootstrap-config.py render-values --config "$BOOTSTRAP_CONFIG_PATH" >"$BOOTSTRAP_VALUES_FILE"
  VALUES_ARGS+=(--values "$BOOTSTRAP_VALUES_FILE")
fi

helm dependency update charts/platform-stack

if cert_manager_install_enabled; then
  echo "Installing cert-manager controller stack before enabling cert-manager custom resources"
  helm_upgrade_install --set certManager.resourcesEnabled=false
  wait_for_cert_manager_crds
  wait_for_cert_manager_deployments
  echo "Re-running install with cert-manager custom resources enabled"
  helm_upgrade_install --set certManager.resourcesEnabled=true
else
  helm_upgrade_install
fi
