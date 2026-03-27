#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE="${PROFILE:-}"
BOOTSTRAP_CONFIG_PATH="${BOOTSTRAP_CONFIG_PATH:-}"
RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-}"
RAW_KUBECONFIG="${KUBECONFIG:-}"
KUBE_CONTEXT="${KUBE_CONTEXT:-}"
VALUES_FILES=()
SET_ARGS=()
REMOTE_DOCKER_SECRET_NAME="${REMOTE_DOCKER_SECRET_NAME:-}"
REMOTE_DOCKER_HOST="${REMOTE_DOCKER_HOST:-}"
REMOTE_DOCKER_PORT="${REMOTE_DOCKER_PORT:-}"
REMOTE_DOCKER_KEY_PATH="${REMOTE_DOCKER_KEY_PATH:-}"
INCUS_VM_NAME="${INCUS_VM_NAME:-openclaw-sandbox}"
INCUS_CONNECTION_INFO_PATH="${INCUS_CONNECTION_INFO_PATH:-}"
BOOTSTRAP_VALUES_FILE=""
REMOTE_DOCKER_OVERRIDE_VALUES_FILE=""
SKIP_SECRETS=0
VERBOSE=0
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
CODER_SANDBOX_IMAGE_TAG="${CODER_SANDBOX_IMAGE_TAG:-openclaw-sandbox-coder:bookworm-slim}"

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

normalize_service_key() {
  case "$1" in
    openclaw|nextcloud|gitea|vaultwarden) echo "$1" ;;
    nextcloud-mcp|nextcloudMcp) echo "nextcloudMcp" ;;
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
    *)
      return 1
      ;;
  esac
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

prepare_openclaw_sandbox_images() {
  local docker_host=""
  if [[ -n "$BOOTSTRAP_VALUES_FILE" ]] && grep -q "$CODER_SANDBOX_IMAGE_TAG" "$BOOTSTRAP_VALUES_FILE"; then
    ./scripts/build-openclaw-sandbox-images.sh --coder-image "$CODER_SANDBOX_IMAGE_TAG"
    if [[ -n "$REMOTE_DOCKER_HOST" && -n "$REMOTE_DOCKER_PORT" ]]; then
      docker_host="ssh://docker-remote@${REMOTE_DOCKER_HOST}:${REMOTE_DOCKER_PORT}"
      load_cmd=(
        ./scripts/openclaw-remote-docker-load-images.sh
        --docker-host "$docker_host"
      )
      if [[ -n "$REMOTE_DOCKER_KEY_PATH" ]]; then
        load_cmd+=(--identity-file "$REMOTE_DOCKER_KEY_PATH")
      fi
      load_cmd+=(--image "$CODER_SANDBOX_IMAGE_TAG")
      "${load_cmd[@]}"
    fi
  fi
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

usage() {
  cat <<USAGE
Usage: $0 --profile <k3d|k3s> [options]

Run the shared bootstrap flow for a prepared cluster.

Options:
  --profile <k3d|k3s>          Supported target profile
  --bootstrap-config <path>    Bootstrap config file (default: ${BOOTSTRAP_CONFIG_PATH})
  --release-name <name>        Helm release name (default: ${RELEASE_NAME})
  --namespace <name>           Kubernetes namespace (default: ${NAMESPACE})
  --kubeconfig <path>          Optional kubeconfig path
  --kube-context <context>     Optional kube context
  --values-file <path>         Extra values file path (repeatable)
  --enable-service <name>      Enable a service (repeatable)
  --disable-service <name>     Disable a service (repeatable)
  --skip-secrets               Skip bootstrap-secrets.sh and only apply the Helm release
  --remote-docker-secret <n>   Override SSH secret name for OpenClaw remote Docker bootstrap
  --remote-docker-host <host>  Override OpenClaw remote Docker SSH host
  --remote-docker-port <port>  Override OpenClaw remote Docker SSH port
  --remote-docker-key <path>   Override OpenClaw remote Docker SSH private key path
  --incus-vm-name <name>       Incus VM name for k3d remote Docker auto-discovery (default: ${INCUS_VM_NAME})
  --incus-connection-info <p>  Incus VM env file for k3d remote Docker auto-discovery
  --verbose                    Stream full command output
  -h, --help                   Show this help message

Supported services: openclaw, nextcloud, nextcloud-mcp, gitea, argo-cd, vaultwarden, postfix-relay, paperless-ngx
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --bootstrap-config) BOOTSTRAP_CONFIG_PATH="$2"; shift 2 ;;
    --release-name) RELEASE_NAME="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --kube-context) KUBE_CONTEXT="$2"; shift 2 ;;
    --values-file) VALUES_FILES+=("$2"); shift 2 ;;
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
    --skip-secrets) SKIP_SECRETS=1; shift ;;
    --remote-docker-secret) REMOTE_DOCKER_SECRET_NAME="$2"; shift 2 ;;
    --remote-docker-host) REMOTE_DOCKER_HOST="$2"; shift 2 ;;
    --remote-docker-port) REMOTE_DOCKER_PORT="$2"; shift 2 ;;
    --remote-docker-key) REMOTE_DOCKER_KEY_PATH="$2"; shift 2 ;;
    --incus-vm-name) INCUS_VM_NAME="$2"; shift 2 ;;
    --incus-connection-info) INCUS_CONNECTION_INFO_PATH="$2"; shift 2 ;;
    --verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$KUBECONFIG_PATH" ]]; then
  KUBECONFIG_PATH="$(normalize_kubeconfig_path "$RAW_KUBECONFIG")"
fi

case "$PROFILE" in
  k3d|k3s) ;;
  *) echo "Missing or unsupported --profile. Use k3d or k3s." >&2; usage; exit 1 ;;
esac

if [[ -z "$INCUS_CONNECTION_INFO_PATH" ]]; then
  INCUS_CONNECTION_INFO_PATH="${HOME}/.local/state/ai-homebase/incus/${INCUS_VM_NAME}.env"
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
  trap 'rm -f "$BOOTSTRAP_VALUES_FILE" "$REMOTE_DOCKER_OVERRIDE_VALUES_FILE"' EXIT
  python3 ./scripts/bootstrap-config.py render-values --config "$BOOTSTRAP_CONFIG_PATH" >"$BOOTSTRAP_VALUES_FILE"
  VALUES_ARGS+=(--values "$BOOTSTRAP_VALUES_FILE")
fi

if [[ -f "$INCUS_CONNECTION_INFO_PATH" ]]; then
  # shellcheck disable=SC1090
  source "$INCUS_CONNECTION_INFO_PATH"
  if [[ -z "$REMOTE_DOCKER_HOST" && -n "${HOST_LISTEN_ADDRESS:-}" ]]; then
    REMOTE_DOCKER_HOST="$HOST_LISTEN_ADDRESS"
  fi
  if [[ -z "$REMOTE_DOCKER_PORT" && -n "${SSH_HOST_PORT:-}" ]]; then
    REMOTE_DOCKER_PORT="$SSH_HOST_PORT"
  fi
fi

if [[ -n "$REMOTE_DOCKER_HOST" && -n "$REMOTE_DOCKER_PORT" ]]; then
  REMOTE_DOCKER_OVERRIDE_VALUES_FILE="$(mktemp /tmp/ai-homebase-bootstrap-remote-docker.XXXXXX.yaml)"
  cat >"$REMOTE_DOCKER_OVERRIDE_VALUES_FILE" <<EOF
openclaw:
  remoteDocker:
    dockerHost: ssh://docker-remote@${REMOTE_DOCKER_HOST}:${REMOTE_DOCKER_PORT}
EOF
  VALUES_ARGS+=(--values "$REMOTE_DOCKER_OVERRIDE_VALUES_FILE")
fi

BOOTSTRAP_SECRETS_CMD=(
  ./scripts/bootstrap-secrets.sh
  --profile "$PROFILE"
  --bootstrap-config "$BOOTSTRAP_CONFIG_PATH"
  --release-name "$RELEASE_NAME"
  --namespace "$NAMESPACE"
)

if [[ -n "$KUBECONFIG_PATH" ]]; then
  BOOTSTRAP_SECRETS_CMD+=(--kubeconfig "$KUBECONFIG_PATH")
fi

if [[ -n "$REMOTE_DOCKER_SECRET_NAME" ]]; then
  BOOTSTRAP_SECRETS_CMD+=(--remote-docker-secret "$REMOTE_DOCKER_SECRET_NAME")
fi
if [[ -n "$REMOTE_DOCKER_HOST" ]]; then
  BOOTSTRAP_SECRETS_CMD+=(--remote-docker-host "$REMOTE_DOCKER_HOST")
fi
if [[ -n "$REMOTE_DOCKER_PORT" ]]; then
  BOOTSTRAP_SECRETS_CMD+=(--remote-docker-port "$REMOTE_DOCKER_PORT")
fi
if [[ -n "$REMOTE_DOCKER_KEY_PATH" ]]; then
  BOOTSTRAP_SECRETS_CMD+=(--remote-docker-key "$REMOTE_DOCKER_KEY_PATH")
fi

if [[ "$VERBOSE" -eq 1 ]]; then
  BOOTSTRAP_SECRETS_CMD+=(--verbose)
fi

if [[ "$SKIP_SECRETS" -eq 0 ]]; then
  "${BOOTSTRAP_SECRETS_CMD[@]}"
fi

prepare_openclaw_sandbox_images

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

if [[ -n "$BOOTSTRAP_CONFIG_PATH" ]]; then
  CODER_GITEA_CMD=(
    ./scripts/bootstrap-coder-gitea.sh
    --bootstrap-config "$BOOTSTRAP_CONFIG_PATH"
    --release-name "$RELEASE_NAME"
    --namespace "$NAMESPACE"
  )
  if [[ -n "$KUBECONFIG_PATH" ]]; then
    CODER_GITEA_CMD+=(--kubeconfig "$KUBECONFIG_PATH")
  fi
  "${CODER_GITEA_CMD[@]}"
fi
