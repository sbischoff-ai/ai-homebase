#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE="${PROFILE:-}"
BOOTSTRAP_CONFIG_PATH="${BOOTSTRAP_CONFIG_PATH:-bootstrap.local.toml}"
RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-}"
RAW_KUBECONFIG="${KUBECONFIG:-}"
K3D_CLUSTER_NAME="${K3D_CLUSTER_NAME:-ai-homebase-dev}"
KUBE_CONTEXT="${KUBE_CONTEXT:-}"
REMOTE_DOCKER_HOST="${REMOTE_DOCKER_HOST:-}"
REMOTE_DOCKER_PORT="${REMOTE_DOCKER_PORT:-}"
REMOTE_DOCKER_KEY_PATH="${REMOTE_DOCKER_KEY_PATH:-}"
INCUS_VM_NAME="${INCUS_VM_NAME:-openclaw-sandbox}"
INCUS_CONNECTION_INFO_PATH="${INCUS_CONNECTION_INFO_PATH:-}"
SHARED_OPENCLAW_STATE_SOURCE="${SHARED_OPENCLAW_STATE_SOURCE:-}"
GITOPS_SECRET_NAME="${GITOPS_SECRET_NAME:-gitops-config-secrets}"
ARGOCD_REPO_SECRET_NAME="${ARGOCD_REPO_SECRET_NAME:-argocd-repo-gitea-gitops}"
GITEA_WAIT_TIMEOUT="${GITEA_WAIT_TIMEOUT:-300s}"
ARGOCD_WAIT_TIMEOUT="${ARGOCD_WAIT_TIMEOUT:-300s}"
ARGOCD_APP_SYNC_TIMEOUT="${ARGOCD_APP_SYNC_TIMEOUT:-300}"
ARGOCD_APP_WAIT_TIMEOUT="${ARGOCD_APP_WAIT_TIMEOUT:-300}"
ARGOCD_SERVER_DEPLOYMENT="${ARGOCD_SERVER_DEPLOYMENT:-${RELEASE_NAME}-argocd-server}"
GITEA_BOOTSTRAP_LOCAL_PORT="${GITEA_BOOTSTRAP_LOCAL_PORT:-13000}"
SKIP_INSTALL=0
GITEA_PORT_FORWARD_PID=""
GITEA_PORT_FORWARD_LOG=""
REPO_WORK_DIR=""
SANDBOX_IMAGES_REPO_WORK_DIR=""
ASKPASS_SCRIPT=""
ARGOCD_REPO_SECRET_MANIFEST=""

usage() {
  cat <<USAGE
Usage: $0 --profile <k3d|k3s> [options]

Bootstrap Argo CD and hand the cluster over to an in-cluster Gitea GitOps repository.

Options:
  --profile <k3d|k3s>        Supported target profile
  --bootstrap-config <path>  Bootstrap config file (default: ${BOOTSTRAP_CONFIG_PATH})
  --release-name <name>      Helm release name (default: ${RELEASE_NAME})
  --namespace <name>         Kubernetes namespace (default: ${NAMESPACE})
  --kubeconfig <path>        Optional kubeconfig path
  --k3d-cluster-name <name>  k3d cluster name for default kubeconfig lookup (default: ${K3D_CLUSTER_NAME})
  --kube-context <context>   Optional kube context
  --remote-docker-host <h>   Override OpenClaw remote Docker SSH host
  --remote-docker-port <p>   Override OpenClaw remote Docker SSH port
  --remote-docker-key <path> Optional SSH private key for the remote Docker image sync step
  --incus-vm-name <name>     Incus VM name for k3d remote Docker auto-discovery (default: ${INCUS_VM_NAME})
  --incus-connection-info <p> Incus VM env file for k3d remote Docker auto-discovery
  --shared-openclaw-state-source <p>
                              Host path shared with OpenClaw and the sandbox VM for first-run CA export
  --skip-install             Skip the internal Argo CD enable/install step and run only the GitOps handoff
  -h, --help                 Show this help message
USAGE
}

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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --bootstrap-config) BOOTSTRAP_CONFIG_PATH="$2"; shift 2 ;;
    --release-name) RELEASE_NAME="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --k3d-cluster-name) K3D_CLUSTER_NAME="$2"; shift 2 ;;
    --kube-context) KUBE_CONTEXT="$2"; shift 2 ;;
    --remote-docker-host) REMOTE_DOCKER_HOST="$2"; shift 2 ;;
    --remote-docker-port) REMOTE_DOCKER_PORT="$2"; shift 2 ;;
    --remote-docker-key) REMOTE_DOCKER_KEY_PATH="$2"; shift 2 ;;
    --incus-vm-name) INCUS_VM_NAME="$2"; shift 2 ;;
    --incus-connection-info) INCUS_CONNECTION_INFO_PATH="$2"; shift 2 ;;
    --shared-openclaw-state-source) SHARED_OPENCLAW_STATE_SOURCE="$2"; shift 2 ;;
    --skip-install) SKIP_INSTALL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$KUBECONFIG_PATH" ]]; then
  KUBECONFIG_PATH="$(normalize_kubeconfig_path "$RAW_KUBECONFIG")"
fi
if [[ "$PROFILE" == "k3d" ]]; then
  DEFAULT_K3D_KUBECONFIG="${HOME}/.kube/k3d-${K3D_CLUSTER_NAME}.yaml"
  if [[ -f "$DEFAULT_K3D_KUBECONFIG" ]] && {
    [[ -z "$KUBECONFIG_PATH" ]] ||
    [[ "$KUBECONFIG_PATH" == "${HOME}/.kube/config" ]] ||
    [[ ! -f "$KUBECONFIG_PATH" ]];
  }; then
    KUBECONFIG_PATH="$DEFAULT_K3D_KUBECONFIG"
  fi
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

case "$PROFILE" in
  k3d|k3s) ;;
  *) echo "Missing or unsupported --profile. Use k3d or k3s." >&2; usage; exit 1 ;;
esac

for cmd in curl git helm kubectl python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required dependency: ${cmd}" >&2
    exit 1
  fi
done

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

step() {
  printf '==> %s\n' "$*"
}

cleanup() {
  if [[ -n "${GITEA_PORT_FORWARD_PID:-}" ]] && kill -0 "$GITEA_PORT_FORWARD_PID" >/dev/null 2>&1; then
    kill "$GITEA_PORT_FORWARD_PID" >/dev/null 2>&1 || true
    wait "$GITEA_PORT_FORWARD_PID" >/dev/null 2>&1 || true
  fi
  rm -f "${GITEA_PORT_FORWARD_LOG:-}" "${ASKPASS_SCRIPT:-}" "${ARGOCD_REPO_SECRET_MANIFEST:-}"
  rm -rf "${REPO_WORK_DIR:-}" "${SANDBOX_IMAGES_REPO_WORK_DIR:-}"
}
trap cleanup EXIT

generate_password() {
  python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(24))
PY
}

read_secret_value() {
  local secret_name="$1"
  local jsonpath="$2"
  local encoded
  encoded="$(
    kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get secret "$secret_name" -o "jsonpath=${jsonpath}" 2>/dev/null || true
  )"
  if [[ -z "$encoded" ]]; then
    return 1
  fi
  printf '%s' "$encoded" | base64 --decode
}

read_workload_env_value() {
  local workload_kind="$1"
  local workload_name="$2"
  local env_name="$3"
  kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get "$workload_kind" "$workload_name" \
    -o "jsonpath={.spec.template.spec.initContainers[?(@.name=='configure-gitea')].env[?(@.name=='${env_name}')].value}" 2>/dev/null || true
}

resolve_gitea_workload() {
  if kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get deployment "${RELEASE_NAME}-gitea" >/dev/null 2>&1; then
    printf 'deployment/%s-gitea' "$RELEASE_NAME"
    return 0
  fi
  if kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get statefulset "${RELEASE_NAME}-gitea" >/dev/null 2>&1; then
    printf 'statefulset/%s-gitea' "$RELEASE_NAME"
    return 0
  fi
  return 1
}

create_and_apply_secret() {
  local secret_name="$1"
  shift
  kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" create secret generic "$secret_name" \
    "$@" \
    --dry-run=client -o yaml | kubectl "${KUBECTL_CONTEXT_ARGS[@]}" apply -f -
}

gitea_api_json() {
  local method="$1"
  local url="$2"
  local auth_user="$3"
  local auth_password="$4"
  local data="${5:-}"
  if [[ -n "$data" ]]; then
    curl -fsS -u "${auth_user}:${auth_password}" \
      -H 'Content-Type: application/json' -X "$method" "$url" --data "$data"
  else
    curl -fsS -u "${auth_user}:${auth_password}" \
      -H 'Content-Type: application/json' -X "$method" "$url"
  fi
}

wait_for_gitea() {
  local workload
  workload="$(resolve_gitea_workload)" || {
    echo "Unable to find Gitea deployment or statefulset for release ${RELEASE_NAME}." >&2
    exit 1
  }
  kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" rollout status "$workload" --timeout "$GITEA_WAIT_TIMEOUT"
  curl -fsS "${GITEA_BASE_URL}/api/v1/version" >/dev/null
}

start_gitea_port_forward() {
  GITEA_PORT_FORWARD_LOG="$(mktemp /tmp/ai-homebase-gitea-port-forward.XXXXXX.log)"
  kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" port-forward \
    "service/${RELEASE_NAME}-gitea-http" \
    "127.0.0.1:${GITEA_BOOTSTRAP_LOCAL_PORT}:3000" \
    >"$GITEA_PORT_FORWARD_LOG" 2>&1 &
  GITEA_PORT_FORWARD_PID=$!

  GITEA_BASE_URL="http://127.0.0.1:${GITEA_BOOTSTRAP_LOCAL_PORT}"
  GITEA_API_URL="${GITEA_BASE_URL}/api/v1"

  for _ in {1..30}; do
    if ! kill -0 "$GITEA_PORT_FORWARD_PID" >/dev/null 2>&1; then
      echo "Gitea port-forward exited early. Log:" >&2
      cat "$GITEA_PORT_FORWARD_LOG" >&2 || true
      exit 1
    fi
    if grep -q "Forwarding from 127.0.0.1:${GITEA_BOOTSTRAP_LOCAL_PORT}" "$GITEA_PORT_FORWARD_LOG"; then
      return 0
    fi
    sleep 1
  done

  echo "Gitea port-forward did not become ready. Log:" >&2
  cat "$GITEA_PORT_FORWARD_LOG" >&2 || true
  exit 1
}

wait_for_argocd() {
  local workloads=(
    "statefulset/${RELEASE_NAME}-argocd-application-controller"
    "deployment/${RELEASE_NAME}-argocd-applicationset-controller"
    "deployment/${RELEASE_NAME}-argocd-dex-server"
    "deployment/${RELEASE_NAME}-argocd-notifications-controller"
    "deployment/${RELEASE_NAME}-argocd-redis"
    "deployment/${RELEASE_NAME}-argocd-repo-server"
    "deployment/${RELEASE_NAME}-argocd-server"
  )
  local workload
  for workload in "${workloads[@]}"; do
    kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" rollout status "$workload" --timeout "$ARGOCD_WAIT_TIMEOUT"
  done
}

argocd_exec() {
  kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" exec "deployment/${ARGOCD_SERVER_DEPLOYMENT}" -- "$@"
}

argocd_login_succeeds() {
  local username="$1"
  local password="$2"
  argocd_exec env ARGOCD_USERNAME="$username" ARGOCD_PASSWORD="$password" sh -ceu '
    cfg="$(mktemp)"
    trap "rm -f \"$cfg\"" EXIT
    argocd --config "$cfg" login 127.0.0.1:8080 \
      --username "$ARGOCD_USERNAME" \
      --password "$ARGOCD_PASSWORD" \
      --plaintext >/dev/null 2>&1
  '
}

set_argocd_admin_password() {
  local current_password="$1"
  local new_password="$2"
  argocd_exec env ARGOCD_CURRENT_PASSWORD="$current_password" ARGOCD_NEW_PASSWORD="$new_password" sh -ceu '
    cfg="$(mktemp)"
    trap "rm -f \"$cfg\"" EXIT
    argocd --config "$cfg" login 127.0.0.1:8080 \
      --username admin \
      --password "$ARGOCD_CURRENT_PASSWORD" \
      --plaintext >/dev/null
    argocd --config "$cfg" account update-password \
      --account admin \
      --current-password "$ARGOCD_CURRENT_PASSWORD" \
      --new-password "$ARGOCD_NEW_PASSWORD" >/dev/null
  '
}

configure_argocd_admin_account() {
  local desired_user="$1"
  local desired_password="$2"
  local bootstrap_password=""

  if [[ -z "$desired_password" ]]; then
    return 0
  fi

  if argocd_login_succeeds "$desired_user" "$desired_password"; then
    step "Argo CD admin credentials already match bootstrap config"
    return 0
  fi

  bootstrap_password="$(read_secret_value argocd-initial-admin-secret '{.data.password}' || true)"
  if [[ -z "$bootstrap_password" ]]; then
    echo "Unable to read argocd-initial-admin-secret and the configured Argo CD admin password did not authenticate." >&2
    exit 1
  fi

  if [[ "$desired_user" == "admin" ]]; then
    step "Setting Argo CD admin password from bootstrap config"
    set_argocd_admin_password "$bootstrap_password" "$desired_password"
    return 0
  fi

  step "Setting Argo CD local admin account ${desired_user} from bootstrap config"
  argocd_exec env \
    ARGOCD_CURRENT_PASSWORD="$bootstrap_password" \
    ARGOCD_TARGET_ACCOUNT="$desired_user" \
    ARGOCD_NEW_PASSWORD="$desired_password" \
    sh -ceu '
      cfg="$(mktemp)"
      trap "rm -f \"$cfg\"" EXIT
      argocd --config "$cfg" login 127.0.0.1:8080 \
        --username admin \
        --password "$ARGOCD_CURRENT_PASSWORD" \
        --plaintext >/dev/null
      argocd --config "$cfg" account update-password \
        --account "$ARGOCD_TARGET_ACCOUNT" \
        --current-password "$ARGOCD_CURRENT_PASSWORD" \
        --new-password "$ARGOCD_NEW_PASSWORD" >/dev/null
    '
}

argocd_application_exists() {
  local app_name="$1"
  kubectl "${KUBECTL_CONTEXT_ARGS[@]}" -n "$NAMESPACE" get application "$app_name" >/dev/null 2>&1
}

wait_for_argocd_application() {
  local app_name="$1"
  local waited=0
  while ! argocd_application_exists "$app_name"; do
    if (( waited >= ARGOCD_APP_WAIT_TIMEOUT )); then
      echo "Timed out waiting for Argo CD application ${app_name} to be created." >&2
      exit 1
    fi
    sleep 2
    waited=$(( waited + 2 ))
  done
}

sync_and_validate_argocd_apps() {
  local username="$1"
  local password="$2"
  local root_app="${RELEASE_NAME}-gitops-root"
  local platform_app="${RELEASE_NAME}-platform-stack"

  wait_for_argocd_application "$root_app"
  wait_for_argocd_application "$platform_app"

  step "Triggering the initial Argo CD sync"
  argocd_exec env \
    ARGOCD_USERNAME="$username" \
    ARGOCD_PASSWORD="$password" \
    ROOT_APP="$root_app" \
    PLATFORM_APP="$platform_app" \
    ARGOCD_APP_SYNC_TIMEOUT="$ARGOCD_APP_SYNC_TIMEOUT" \
    sh -ceu '
      cfg="$(mktemp)"
      trap "rm -f \"$cfg\"" EXIT
      argocd --config "$cfg" login 127.0.0.1:8080 \
        --username "$ARGOCD_USERNAME" \
        --password "$ARGOCD_PASSWORD" \
        --plaintext >/dev/null
      argocd --config "$cfg" app sync \
        "$ROOT_APP" \
        "$PLATFORM_APP" \
        --timeout "$ARGOCD_APP_SYNC_TIMEOUT"
    '

  step "Waiting for Argo CD applications to become Synced and Healthy"
  argocd_exec env \
    ARGOCD_USERNAME="$username" \
    ARGOCD_PASSWORD="$password" \
    ROOT_APP="$root_app" \
    PLATFORM_APP="$platform_app" \
    ARGOCD_APP_WAIT_TIMEOUT="$ARGOCD_APP_WAIT_TIMEOUT" \
    sh -ceu '
      cfg="$(mktemp)"
      trap "rm -f \"$cfg\"" EXIT
      argocd --config "$cfg" login 127.0.0.1:8080 \
        --username "$ARGOCD_USERNAME" \
        --password "$ARGOCD_PASSWORD" \
        --plaintext >/dev/null
      argocd --config "$cfg" app wait \
        "$ROOT_APP" \
        "$PLATFORM_APP" \
        --sync \
        --health \
        --timeout "$ARGOCD_APP_WAIT_TIMEOUT"
    '
}

seed_memgraph() {
  local seed_cmd=(
    ./scripts/bootstrap-memgraph.sh
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

build_admin_user_payload() {
  python3 - "$@" <<'PY'
import json
import sys

username, email, password = sys.argv[1:4]
print(json.dumps({
    "username": username,
    "email": email,
    "password": password,
    "must_change_password": False,
    "send_notify": False,
}))
PY
}

build_repo_payload() {
  python3 - "$@" <<'PY'
import json
import sys

name, branch, private = sys.argv[1:4]
print(json.dumps({
    "name": name,
    "private": private == "true",
    "default_branch": branch,
    "auto_init": False,
}))
PY
}

build_repo_secret_manifest() {
  python3 - "$@" <<'PY'
import sys

namespace, name, url, username, password = sys.argv[1:6]
print(f"""apiVersion: v1
kind: Secret
metadata:
  name: {name}
  namespace: {namespace}
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: {url}
  username: {username}
  password: {password}
  insecure: "true"
""")
PY
}

push_bootstrap_repo() {
  local repo_dir="$1"
  local remote_url="$2"
  local askpass_script="$3"
  local repo_branch="$4"
  local commit_message="$5"

  (
    cd "$repo_dir"
    git init -b "$repo_branch" >/dev/null
    git add .
    git -c user.name="$CODER_GITEA_USERNAME" -c user.email="$CODER_GITEA_EMAIL" commit -m "$commit_message" >/dev/null
    git remote add origin "$remote_url"
    GIT_TERMINAL_PROMPT=0 \
    GIT_USERNAME="$CODER_GITEA_USERNAME" \
    GIT_PASSWORD="$CODER_GITEA_PASSWORD" \
    git -c core.askPass="$askpass_script" push --force origin "HEAD:${repo_branch}" >/dev/null
  )
}

step "Validating bootstrap config"
eval "$(python3 ./scripts/bootstrap-config.py shell-vars --config "$BOOTSTRAP_CONFIG_PATH")"

if [[ -z "$GITOPS_CLUSTER_NAME" ]]; then
  GITOPS_CLUSTER_NAME="$RELEASE_NAME"
fi

step "Checking base platform release"
helm "${HELM_CONTEXT_ARGS[@]}" status "$RELEASE_NAME" --namespace "$NAMESPACE" >/dev/null

GITEA_ADMIN_USERNAME="$(read_secret_value gitea-admin-secret '{.data.username}' || true)"
if [[ -z "${GITEA_ADMIN_USERNAME}" ]]; then
  GITEA_ADMIN_USERNAME="${ADMIN_USERNAME:-}"
fi
GITEA_ADMIN_PASSWORD="$(read_secret_value gitea-admin-secret '{.data.password}' || true)"
if [[ -z "${GITEA_ADMIN_PASSWORD}" ]]; then
  GITEA_ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
fi
if [[ -z "${GITEA_ADMIN_USERNAME}" ]]; then
  GITEA_ADMIN_USERNAME="$(read_workload_env_value deployment "${RELEASE_NAME}-gitea" GITEA_ADMIN_USERNAME)"
fi
if [[ -z "${GITEA_ADMIN_PASSWORD}" ]]; then
  GITEA_ADMIN_PASSWORD="$(read_workload_env_value deployment "${RELEASE_NAME}-gitea" GITEA_ADMIN_PASSWORD)"
fi
if [[ -z "${GITEA_ADMIN_USERNAME}" ]]; then
  GITEA_ADMIN_USERNAME="$(read_workload_env_value statefulset "${RELEASE_NAME}-gitea" GITEA_ADMIN_USERNAME)"
fi
if [[ -z "${GITEA_ADMIN_PASSWORD}" ]]; then
  GITEA_ADMIN_PASSWORD="$(read_workload_env_value statefulset "${RELEASE_NAME}-gitea" GITEA_ADMIN_PASSWORD)"
fi
if [[ -z "${GITEA_ADMIN_USERNAME}" || -z "${GITEA_ADMIN_PASSWORD}" ]]; then
  echo "Unable to resolve Gitea admin credentials from gitea-admin-secret or bootstrap config." >&2
  exit 1
fi
GITEA_EXTERNAL_BASE_URL="http://${GITEA_HOST}"
GITEA_BASE_URL="${GITEA_EXTERNAL_BASE_URL}"
GITEA_API_URL="${GITEA_BASE_URL}/api/v1"

CONFIG_CODER_GITEA_PASSWORD="${CODER_GITEA_PASSWORD:-}"
if CODER_GITEA_PASSWORD="$(read_secret_value "$GITOPS_SECRET_NAME" '{.data.CODER_GITEA_PASSWORD}')"; then
  :
elif CODER_GITEA_PASSWORD="$(read_secret_value "$GITOPS_SECRET_NAME" '{.data.GITOPS_ROBOT_PASSWORD}')"; then
  :
elif CODER_GITEA_PASSWORD="$(read_secret_value "coder-credentials" '{.data.CODER_GITEA_PASSWORD}')"; then
  :
elif [[ -n "${CONFIG_CODER_GITEA_PASSWORD}" ]]; then
  CODER_GITEA_PASSWORD="${CONFIG_CODER_GITEA_PASSWORD}"
else
  CODER_GITEA_PASSWORD="$(generate_password)"
fi

step "Applying bootstrap secrets before the GitOps handoff"
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
if [[ -n "$REMOTE_DOCKER_HOST" ]]; then
  BOOTSTRAP_SECRETS_CMD+=(--remote-docker-host "$REMOTE_DOCKER_HOST")
fi
if [[ -n "$REMOTE_DOCKER_PORT" ]]; then
  BOOTSTRAP_SECRETS_CMD+=(--remote-docker-port "$REMOTE_DOCKER_PORT")
fi
if [[ -n "$REMOTE_DOCKER_KEY_PATH" ]]; then
  BOOTSTRAP_SECRETS_CMD+=(--remote-docker-key "$REMOTE_DOCKER_KEY_PATH")
fi
"${BOOTSTRAP_SECRETS_CMD[@]}"

if [[ "$SKIP_INSTALL" -eq 0 ]]; then
  step "Installing Argo CD through the existing Helm path"
  INSTALL_CMD=(
    ./scripts/bootstrap-stack.sh
    --profile "$PROFILE"
    --bootstrap-config "$BOOTSTRAP_CONFIG_PATH"
    --release-name "$RELEASE_NAME"
    --namespace "$NAMESPACE"
    --skip-gitops
    --enable-service argo-cd
  )
  if [[ -n "$KUBECONFIG_PATH" ]]; then
    INSTALL_CMD+=(--kubeconfig "$KUBECONFIG_PATH")
  fi
  if [[ -n "$KUBE_CONTEXT" ]]; then
    INSTALL_CMD+=(--kube-context "$KUBE_CONTEXT")
  fi
  if [[ -n "$REMOTE_DOCKER_HOST" ]]; then
    INSTALL_CMD+=(--remote-docker-host "$REMOTE_DOCKER_HOST")
  fi
  if [[ -n "$REMOTE_DOCKER_PORT" ]]; then
    INSTALL_CMD+=(--remote-docker-port "$REMOTE_DOCKER_PORT")
  fi
  if [[ -n "$REMOTE_DOCKER_KEY_PATH" ]]; then
    INSTALL_CMD+=(--remote-docker-key "$REMOTE_DOCKER_KEY_PATH")
  fi
  if [[ -n "$INCUS_CONNECTION_INFO_PATH" ]]; then
    INSTALL_CMD+=(--incus-connection-info "$INCUS_CONNECTION_INFO_PATH")
  fi
  if [[ -n "$SHARED_OPENCLAW_STATE_SOURCE" ]]; then
    INSTALL_CMD+=(--shared-openclaw-state-source "$SHARED_OPENCLAW_STATE_SOURCE")
  fi
  "${INSTALL_CMD[@]}"
fi

step "Waiting for Gitea and Argo CD"
start_gitea_port_forward
wait_for_gitea
wait_for_argocd
configure_argocd_admin_account "${ARGOCD_ADMIN_USER:-admin}" "${ARGOCD_ADMIN_PASSWORD:-}"

step "Creating or updating the coder GitOps user in Gitea"
ROBOT_USER_PAYLOAD="$(build_admin_user_payload "$CODER_GITEA_USERNAME" "$CODER_GITEA_EMAIL" "$CODER_GITEA_PASSWORD")"
ROBOT_USER_STATUS="$(
  curl -sS -u "${GITEA_ADMIN_USERNAME}:${GITEA_ADMIN_PASSWORD}" \
    -o /dev/null -w '%{http_code}' \
    "${GITEA_API_URL}/users/${CODER_GITEA_USERNAME}"
)"
case "$ROBOT_USER_STATUS" in
  200)
    step "Coder Gitea user ${CODER_GITEA_USERNAME} already exists; preserving existing credentials"
    ;;
  404)
    gitea_api_json POST "${GITEA_API_URL}/admin/users" "$GITEA_ADMIN_USERNAME" "$GITEA_ADMIN_PASSWORD" "$ROBOT_USER_PAYLOAD" >/dev/null
    ;;
  *)
    echo "Unexpected Gitea user lookup status: ${ROBOT_USER_STATUS}" >&2
    exit 1
    ;;
esac
 
step "Creating or updating the GitOps repo in Gitea"
REPO_STATUS="$(
  curl -sS -u "${CODER_GITEA_USERNAME}:${CODER_GITEA_PASSWORD}" \
    -o /dev/null -w '%{http_code}' \
    "${GITEA_API_URL}/repos/${CODER_GITEA_USERNAME}/${GITOPS_REPO_NAME}"
)"
if [[ "$REPO_STATUS" == "404" ]]; then
  REPO_PAYLOAD="$(build_repo_payload "$GITOPS_REPO_NAME" "$GITOPS_REPO_BRANCH" "$GITOPS_REPO_PRIVATE")"
  gitea_api_json POST "${GITEA_API_URL}/user/repos" "$CODER_GITEA_USERNAME" "$CODER_GITEA_PASSWORD" "$REPO_PAYLOAD" >/dev/null
elif [[ "$REPO_STATUS" != "200" ]]; then
  echo "Unexpected Gitea repo lookup status: ${REPO_STATUS}" >&2
  exit 1
fi

step "Creating or updating the sandbox-images repo in Gitea"
SANDBOX_REPO_STATUS="$(
  curl -sS -u "${CODER_GITEA_USERNAME}:${CODER_GITEA_PASSWORD}" \
    -o /dev/null -w '%{http_code}' \
    "${GITEA_API_URL}/repos/${CODER_GITEA_USERNAME}/${SANDBOX_IMAGES_REPO_NAME}"
)"
if [[ "$SANDBOX_REPO_STATUS" == "404" ]]; then
  SANDBOX_REPO_PAYLOAD="$(build_repo_payload "$SANDBOX_IMAGES_REPO_NAME" "$GITOPS_REPO_BRANCH" "$GITOPS_REPO_PRIVATE")"
  gitea_api_json POST "${GITEA_API_URL}/user/repos" "$CODER_GITEA_USERNAME" "$CODER_GITEA_PASSWORD" "$SANDBOX_REPO_PAYLOAD" >/dev/null
elif [[ "$SANDBOX_REPO_STATUS" != "200" ]]; then
  echo "Unexpected sandbox-images Gitea repo lookup status: ${SANDBOX_REPO_STATUS}" >&2
  exit 1
fi

EXTERNAL_REPO_URL="${GITEA_BASE_URL}/${CODER_GITEA_USERNAME}/${GITOPS_REPO_NAME}.git"
DISPLAY_REPO_URL="${GITEA_EXTERNAL_BASE_URL}/${CODER_GITEA_USERNAME}/${GITOPS_REPO_NAME}.git"
INTERNAL_REPO_URL="http://${RELEASE_NAME}-gitea-http.${NAMESPACE}.svc.cluster.local:3000/${CODER_GITEA_USERNAME}/${GITOPS_REPO_NAME}.git"
SANDBOX_IMAGES_EXTERNAL_REPO_URL="${GITEA_BASE_URL}/${CODER_GITEA_USERNAME}/${SANDBOX_IMAGES_REPO_NAME}.git"
SANDBOX_IMAGES_DISPLAY_REPO_URL="${GITEA_EXTERNAL_BASE_URL}/${CODER_GITEA_USERNAME}/${SANDBOX_IMAGES_REPO_NAME}.git"

step "Rendering and pushing the GitOps repo snapshot"
REPO_WORK_DIR="$(mktemp -d /tmp/ai-homebase-gitops-repo.XXXXXX)"
SANDBOX_IMAGES_REPO_WORK_DIR="$(mktemp -d /tmp/ai-homebase-sandbox-images-repo.XXXXXX)"
ASKPASS_SCRIPT="$(mktemp /tmp/ai-homebase-gitops-askpass.XXXXXX)"
ARGOCD_REPO_SECRET_MANIFEST="$(mktemp /tmp/ai-homebase-argocd-repo-secret.XXXXXX.yaml)"

cat >"$ASKPASS_SCRIPT" <<'SH'
#!/usr/bin/env bash
case "$1" in
  *Username*) printf '%s' "${GIT_USERNAME:?}" ;;
  *) printf '%s' "${GIT_PASSWORD:?}" ;;
esac
SH
chmod 0700 "$ASKPASS_SCRIPT"

RENDER_GITOPS_CMD=(
  python3 ./scripts/render-gitops-repo.py
  --output-dir "$REPO_WORK_DIR"
  --bootstrap-config "$BOOTSTRAP_CONFIG_PATH"
  --profile "$PROFILE"
  --cluster-name "$GITOPS_CLUSTER_NAME"
  --release-name "$RELEASE_NAME"
  --namespace "$NAMESPACE"
  --repo-url "$INTERNAL_REPO_URL"
  --repo-branch "$GITOPS_REPO_BRANCH"
  --project "$GITOPS_PROJECT"
)
if [[ -n "$REMOTE_DOCKER_HOST" ]]; then
  RENDER_GITOPS_CMD+=(--remote-docker-host "$REMOTE_DOCKER_HOST")
fi
if [[ -n "$REMOTE_DOCKER_PORT" ]]; then
  RENDER_GITOPS_CMD+=(--remote-docker-port "$REMOTE_DOCKER_PORT")
fi
"${RENDER_GITOPS_CMD[@]}"

python3 ./scripts/render-sandbox-images-repo.py \
  --output-dir "$SANDBOX_IMAGES_REPO_WORK_DIR" \
  --registry-host "$REGISTRY_HOST" \
  --repo-owner "$CODER_GITEA_USERNAME" \
  --gitops-repo-name "$GITOPS_REPO_NAME"

push_bootstrap_repo "$REPO_WORK_DIR" "$EXTERNAL_REPO_URL" "$ASKPASS_SCRIPT" "$GITOPS_REPO_BRANCH" "Bootstrap GitOps repo"
push_bootstrap_repo "$SANDBOX_IMAGES_REPO_WORK_DIR" "$SANDBOX_IMAGES_EXTERNAL_REPO_URL" "$ASKPASS_SCRIPT" "$GITOPS_REPO_BRANCH" "Bootstrap sandbox images repo"

step "Persisting GitOps bootstrap credentials"
create_and_apply_secret "$GITOPS_SECRET_NAME" \
  --from-literal=CODER_GITEA_USERNAME="$CODER_GITEA_USERNAME" \
  --from-literal=CODER_GITEA_EMAIL="$CODER_GITEA_EMAIL" \
  --from-literal=CODER_GITEA_PASSWORD="$CODER_GITEA_PASSWORD" \
  --from-literal=GITOPS_REPO_NAME="$GITOPS_REPO_NAME" \
  --from-literal=SANDBOX_IMAGES_REPO_NAME="$SANDBOX_IMAGES_REPO_NAME" \
  --from-literal=GITOPS_REPO_BRANCH="$GITOPS_REPO_BRANCH" \
  --from-literal=GITOPS_PROJECT="$GITOPS_PROJECT"

step "Registering the GitOps repo in Argo CD"
build_repo_secret_manifest "$NAMESPACE" "$ARGOCD_REPO_SECRET_NAME" "$INTERNAL_REPO_URL" "$CODER_GITEA_USERNAME" "$CODER_GITEA_PASSWORD" \
  >"$ARGOCD_REPO_SECRET_MANIFEST"
kubectl "${KUBECTL_CONTEXT_ARGS[@]}" apply -f "$ARGOCD_REPO_SECRET_MANIFEST"

step "Applying the Argo CD project and applications"
kubectl "${KUBECTL_CONTEXT_ARGS[@]}" apply -f "${REPO_WORK_DIR}/gitops/clusters/${GITOPS_CLUSTER_NAME}/project.yaml"
kubectl "${KUBECTL_CONTEXT_ARGS[@]}" apply -f "${REPO_WORK_DIR}/gitops/clusters/${GITOPS_CLUSTER_NAME}/applications/platform-stack.yaml"
kubectl "${KUBECTL_CONTEXT_ARGS[@]}" apply -f "${REPO_WORK_DIR}/gitops/clusters/${GITOPS_CLUSTER_NAME}/root-application.yaml"

sync_and_validate_argocd_apps "${ARGOCD_ADMIN_USER:-admin}" "${ARGOCD_ADMIN_PASSWORD:-}"
seed_memgraph

printf 'GitOps bootstrap complete.\n'
printf '  Argo CD URL: http://%s\n' "$ARGOCD_HOST"
printf '  Gitea GitOps repo: %s\n' "$DISPLAY_REPO_URL"
printf '  Gitea sandbox images repo: %s\n' "$SANDBOX_IMAGES_DISPLAY_REPO_URL"
printf '  Argo CD repository URL: %s\n' "$INTERNAL_REPO_URL"
printf '  Argo CD project: %s\n' "$GITOPS_PROJECT"
