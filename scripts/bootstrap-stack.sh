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
SKIP_GITOPS=0
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
DEFAULT_SANDBOX_IMAGE_TAG="${DEFAULT_SANDBOX_IMAGE_TAG:-openclaw-sandbox:bookworm-slim}"
ARCHIVIST_SANDBOX_IMAGE_TAG="${ARCHIVIST_SANDBOX_IMAGE_TAG:-openclaw-sandbox-archivist:bookworm-slim}"
GATEWAY_IMAGE_TAG="${GATEWAY_IMAGE_TAG:-openclaw-remote-docker:bookworm-slim}"
CANONICAL_DEFAULT_SANDBOX_IMAGE="${CANONICAL_DEFAULT_SANDBOX_IMAGE:-}"
CANONICAL_ARCHIVIST_SANDBOX_IMAGE="${CANONICAL_ARCHIVIST_SANDBOX_IMAGE:-}"
CANONICAL_CODER_SANDBOX_IMAGE="${CANONICAL_CODER_SANDBOX_IMAGE:-}"
REGISTRY_HOST_VALUE="${REGISTRY_HOST_VALUE:-}"
REGISTRY_USERNAME_VALUE="${REGISTRY_USERNAME_VALUE:-}"
REGISTRY_PASSWORD_VALUE="${REGISTRY_PASSWORD_VALUE:-}"
PUBLISH_SOURCE_IMAGES=()
PUBLISH_TARGET_IMAGES=()

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
    openclaw|nextcloud|gitea|registry|vaultwarden) echo "$1" ;;
    nextcloud-mcp|nextcloudMcp) echo "nextcloudMcp" ;;
    qdrant|qdrantMcp|qdrant-mcp)
      if [[ "$1" == qdrant-mcp || "$1" == qdrantMcp ]]; then echo "qdrantMcp"; else echo "qdrant"; fi ;;
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

current_kube_context() {
  if [[ -n "$KUBE_CONTEXT" ]]; then
    printf '%s\n' "$KUBE_CONTEXT"
    return 0
  fi
  kubectl "${KUBECTL_CONTEXT_ARGS[@]}" config current-context
}

values_reference() {
  local needle="$1"
  local file=""

  for file in "${VALUES_FILES[@]}"; do
    if [[ -n "$file" && -f "$file" ]] && grep -q "$needle" "$file"; then
      return 0
    fi
  done

  if [[ -n "$BOOTSTRAP_VALUES_FILE" && -f "$BOOTSTRAP_VALUES_FILE" ]] && grep -q "$needle" "$BOOTSTRAP_VALUES_FILE"; then
    return 0
  fi

  return 1
}

import_image_into_k3d_cluster() {
  local image="$1"
  local current_context cluster_name

  current_context="$(current_kube_context)"
  if [[ "$current_context" != k3d-* ]]; then
    echo "Skipping k3d image import for ${image}; current context ${current_context} is not a k3d context."
    return 0
  fi

  cluster_name="${current_context#k3d-}"
  k3d image import -c "$cluster_name" "$image"
}

prepare_openclaw_runtime_images() {
  local docker_host=""
  local build_args=()
  local gateway_image_needed=0
  local default_image_needed=0
  local archivist_image_needed=0
  local coder_image_needed=0

  if values_reference "repository: ${GATEWAY_IMAGE_TAG%%:*}" || values_reference "$GATEWAY_IMAGE_TAG"; then
    gateway_image_needed=1
    build_args+=(--gateway-image "$GATEWAY_IMAGE_TAG")
  fi
  if values_reference "openclaw-sandbox:"; then
    default_image_needed=1
    build_args+=(--base-image "$DEFAULT_SANDBOX_IMAGE_TAG")
  fi
  if values_reference "openclaw-sandbox-archivist:"; then
    archivist_image_needed=1
    build_args+=(--archivist-image "$ARCHIVIST_SANDBOX_IMAGE_TAG")
  fi
  if values_reference "openclaw-sandbox-coder:"; then
    coder_image_needed=1
    build_args+=(--coder-image "$CODER_SANDBOX_IMAGE_TAG")
  fi

  if [[ ${#build_args[@]} -eq 0 ]]; then
    return 0
  fi

  ./scripts/build-openclaw-sandbox-images.sh "${build_args[@]}"

  if [[ "$PROFILE" == "k3d" && "$gateway_image_needed" -eq 1 ]]; then
    import_image_into_k3d_cluster "$GATEWAY_IMAGE_TAG"
  fi

  if [[ ( "$default_image_needed" -eq 1 || "$archivist_image_needed" -eq 1 || "$coder_image_needed" -eq 1 ) && -n "$REMOTE_DOCKER_HOST" && -n "$REMOTE_DOCKER_PORT" ]]; then
    docker_host="ssh://docker-remote@${REMOTE_DOCKER_HOST}:${REMOTE_DOCKER_PORT}"
    load_cmd=(
      ./scripts/openclaw-remote-docker-load-images.sh
      --docker-host "$docker_host"
    )
    if [[ -n "$REMOTE_DOCKER_KEY_PATH" ]]; then
      load_cmd+=(--identity-file "$REMOTE_DOCKER_KEY_PATH")
    fi
    if [[ "$default_image_needed" -eq 1 ]]; then
      load_cmd+=(--image "$DEFAULT_SANDBOX_IMAGE_TAG")
    fi
    if [[ "$archivist_image_needed" -eq 1 ]]; then
      load_cmd+=(--image "$ARCHIVIST_SANDBOX_IMAGE_TAG")
    fi
    if [[ "$coder_image_needed" -eq 1 ]]; then
      load_cmd+=(--image "$CODER_SANDBOX_IMAGE_TAG")
    fi
    "${load_cmd[@]}"

    publish_cmd=(
        ./scripts/openclaw-remote-docker-publish-images.sh
        --tag-only
        --docker-host "$docker_host"
    )
    if [[ -n "$REMOTE_DOCKER_KEY_PATH" ]]; then
      publish_cmd+=(--identity-file "$REMOTE_DOCKER_KEY_PATH")
    fi
    if [[ "$default_image_needed" -eq 1 && -n "$CANONICAL_DEFAULT_SANDBOX_IMAGE" ]]; then
      publish_cmd+=(--source-image "$DEFAULT_SANDBOX_IMAGE_TAG" --target-image "$CANONICAL_DEFAULT_SANDBOX_IMAGE")
      PUBLISH_SOURCE_IMAGES+=("$DEFAULT_SANDBOX_IMAGE_TAG")
      PUBLISH_TARGET_IMAGES+=("$CANONICAL_DEFAULT_SANDBOX_IMAGE")
    fi
    if [[ "$archivist_image_needed" -eq 1 && -n "$CANONICAL_ARCHIVIST_SANDBOX_IMAGE" ]]; then
      publish_cmd+=(--source-image "$ARCHIVIST_SANDBOX_IMAGE_TAG" --target-image "$CANONICAL_ARCHIVIST_SANDBOX_IMAGE")
      PUBLISH_SOURCE_IMAGES+=("$ARCHIVIST_SANDBOX_IMAGE_TAG")
      PUBLISH_TARGET_IMAGES+=("$CANONICAL_ARCHIVIST_SANDBOX_IMAGE")
    fi
    if [[ "$coder_image_needed" -eq 1 && -n "$CANONICAL_CODER_SANDBOX_IMAGE" ]]; then
      publish_cmd+=(--source-image "$CODER_SANDBOX_IMAGE_TAG" --target-image "$CANONICAL_CODER_SANDBOX_IMAGE")
      PUBLISH_SOURCE_IMAGES+=("$CODER_SANDBOX_IMAGE_TAG")
      PUBLISH_TARGET_IMAGES+=("$CANONICAL_CODER_SANDBOX_IMAGE")
    fi
    if [[ ${#publish_cmd[@]} -gt 4 ]]; then
      "${publish_cmd[@]}"
    fi
  fi
}

publish_runtime_images_to_registry() {
  local registry_deployment="${RELEASE_NAME}-registry"
  local registry_service="${RELEASE_NAME}-registry"
  local registry_secret="registry-auth-secret"
  local port_forward_log=""
  local port_forward_pid=""
  local target_image=""
  local source_image=""
  local local_registry_host="127.0.0.1:5000"
  local local_target_image=""
  local effective_registry_username="${REGISTRY_USERNAME_VALUE:-}"
  local effective_registry_password="${REGISTRY_PASSWORD_VALUE:-}"

  if [[ ${#PUBLISH_SOURCE_IMAGES[@]} -eq 0 ]]; then
    return 0
  fi
  if kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get secret "$registry_secret" >/dev/null 2>&1; then
    effective_registry_username="$(kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get secret "$registry_secret" -o jsonpath='{.data.username}' | base64 -d)"
    effective_registry_password="$(kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get secret "$registry_secret" -o jsonpath='{.data.password}' | base64 -d)"
  fi
  if [[ -z "$REGISTRY_HOST_VALUE" || -z "$effective_registry_username" || -z "$effective_registry_password" ]]; then
    return 0
  fi

  kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" rollout status "deployment/${registry_deployment}" --timeout 300s

  port_forward_log="$(mktemp /tmp/ai-homebase-registry-port-forward.XXXXXX.log)"
  kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" port-forward "service/${registry_service}" 5000:5000 >"$port_forward_log" 2>&1 &
  port_forward_pid=$!
  cleanup_registry_port_forward() {
    if [[ -n "${port_forward_pid:-}" ]] && kill -0 "${port_forward_pid}" >/dev/null 2>&1; then
      kill "${port_forward_pid}" >/dev/null 2>&1 || true
      wait "${port_forward_pid}" >/dev/null 2>&1 || true
    fi
    rm -f "${port_forward_log:-}"
  }
  trap 'cleanup_registry_port_forward; rm -f "$BOOTSTRAP_VALUES_FILE" "$REMOTE_DOCKER_OVERRIDE_VALUES_FILE"' EXIT

  for _ in {1..30}; do
    if [[ "$(curl --silent --output /dev/null --write-out '%{http_code}' http://${local_registry_host}/v2/ 2>/dev/null || true)" =~ ^(200|401)$ ]]; then
      break
    fi
    sleep 1
  done
  if [[ ! "$(curl --silent --output /dev/null --write-out '%{http_code}' http://${local_registry_host}/v2/ 2>/dev/null || true)" =~ ^(200|401)$ ]]; then
    echo "Registry port-forward did not become ready. Log:" >&2
    cat "$port_forward_log" >&2
    exit 1
  fi

  printf '%s' "$effective_registry_password" | docker login "$local_registry_host" --username "$effective_registry_username" --password-stdin >/dev/null

  for i in "${!PUBLISH_SOURCE_IMAGES[@]}"; do
    source_image="${PUBLISH_SOURCE_IMAGES[$i]}"
    target_image="${PUBLISH_TARGET_IMAGES[$i]}"
    local_target_image="${local_registry_host}/${target_image#*/}"
    docker tag "$source_image" "$local_target_image"
    docker push "$local_target_image" >/dev/null
  done

  cleanup_registry_port_forward
  trap 'rm -f "$BOOTSTRAP_VALUES_FILE" "$REMOTE_DOCKER_OVERRIDE_VALUES_FILE"' EXIT
}

seed_openclaw_cron_jobs() {
  local seed_cmd=(
    ./scripts/bootstrap-openclaw-cron.sh
    --release-name "$RELEASE_NAME"
    --namespace "$NAMESPACE"
  )
  if [[ -n "$KUBECONFIG_PATH" ]]; then
    seed_cmd+=(--kubeconfig "$KUBECONFIG_PATH")
  fi
  if [[ -n "$KUBE_CONTEXT" ]]; then
    seed_cmd+=(--kube-context "$KUBE_CONTEXT")
  fi
  "${seed_cmd[@]}"
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
  --skip-gitops                Skip the integrated GitOps handoff and Argo CD validation
  --remote-docker-secret <n>   Override SSH secret name for OpenClaw remote Docker bootstrap
  --remote-docker-host <host>  Override OpenClaw remote Docker SSH host
  --remote-docker-port <port>  Override OpenClaw remote Docker SSH port
  --remote-docker-key <path>   Override OpenClaw remote Docker SSH private key path
  --incus-vm-name <name>       Incus VM name for k3d remote Docker auto-discovery (default: ${INCUS_VM_NAME})
  --incus-connection-info <p>  Incus VM env file for k3d remote Docker auto-discovery
  --verbose                    Stream full command output
  -h, --help                   Show this help message

Supported services: openclaw, nextcloud, nextcloud-mcp, gitea, registry, argo-cd, vaultwarden, postfix-relay, paperless-ngx, qdrant, qdrant-mcp
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
    --skip-gitops) SKIP_GITOPS=1; shift ;;
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
  eval "$(python3 ./scripts/bootstrap-config.py shell-vars --config "$BOOTSTRAP_CONFIG_PATH")"
  CANONICAL_DEFAULT_SANDBOX_IMAGE="${OPENCLAW_DEFAULT_SANDBOX_IMAGE:-$CANONICAL_DEFAULT_SANDBOX_IMAGE}"
  CANONICAL_ARCHIVIST_SANDBOX_IMAGE="${OPENCLAW_ARCHIVIST_SANDBOX_IMAGE:-$CANONICAL_ARCHIVIST_SANDBOX_IMAGE}"
  CANONICAL_CODER_SANDBOX_IMAGE="${OPENCLAW_CODER_SANDBOX_IMAGE:-$CANONICAL_CODER_SANDBOX_IMAGE}"
  REGISTRY_HOST_VALUE="${REGISTRY_HOST:-$REGISTRY_HOST_VALUE}"
  REGISTRY_USERNAME_VALUE="${REGISTRY_USERNAME:-$REGISTRY_USERNAME_VALUE}"
  REGISTRY_PASSWORD_VALUE="${REGISTRY_PASSWORD:-$REGISTRY_PASSWORD_VALUE}"
  VALUES_ARGS+=(--values "$BOOTSTRAP_VALUES_FILE")
fi

if [[ -z "$INCUS_CONNECTION_INFO_PATH" ]]; then
  INCUS_CONNECTION_INFO_PATH="${HOME}/.local/state/ai-homebase/incus/${INCUS_VM_NAME}.env"
fi
if [[ -z "$REMOTE_DOCKER_KEY_PATH" ]]; then
  REMOTE_DOCKER_KEY_PATH="${HOME}/.local/state/ai-homebase/incus/${INCUS_VM_NAME}-id_ed25519"
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

prepare_openclaw_runtime_images

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

publish_runtime_images_to_registry
seed_openclaw_cron_jobs

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

if [[ -n "$BOOTSTRAP_CONFIG_PATH" && "$SKIP_GITOPS" -eq 0 ]]; then
  GITOPS_CMD=(
    ./scripts/bootstrap-gitops.sh
    --profile "$PROFILE"
    --bootstrap-config "$BOOTSTRAP_CONFIG_PATH"
    --release-name "$RELEASE_NAME"
    --namespace "$NAMESPACE"
  )
  if [[ -n "$KUBECONFIG_PATH" ]]; then
    GITOPS_CMD+=(--kubeconfig "$KUBECONFIG_PATH")
  fi
  if [[ -n "$KUBE_CONTEXT" ]]; then
    GITOPS_CMD+=(--kube-context "$KUBE_CONTEXT")
  fi
  if [[ -n "$REMOTE_DOCKER_HOST" ]]; then
    GITOPS_CMD+=(--remote-docker-host "$REMOTE_DOCKER_HOST")
  fi
  if [[ -n "$REMOTE_DOCKER_PORT" ]]; then
    GITOPS_CMD+=(--remote-docker-port "$REMOTE_DOCKER_PORT")
  fi
  if [[ -n "$REMOTE_DOCKER_KEY_PATH" ]]; then
    GITOPS_CMD+=(--remote-docker-key "$REMOTE_DOCKER_KEY_PATH")
  fi
  if [[ -n "$INCUS_CONNECTION_INFO_PATH" ]]; then
    GITOPS_CMD+=(--incus-connection-info "$INCUS_CONNECTION_INFO_PATH")
  fi
  "${GITOPS_CMD[@]}"
fi
