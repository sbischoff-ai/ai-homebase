#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE="${PROFILE:-}"
BOOTSTRAP_CONFIG_PATH="${BOOTSTRAP_CONFIG_PATH:-bootstrap.local.toml}"
RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${KUBECONFIG:-}}"
KUBE_CONTEXT="${KUBE_CONTEXT:-}"
GITOPS_SECRET_NAME="${GITOPS_SECRET_NAME:-gitops-config-secrets}"
ARGOCD_REPO_SECRET_NAME="${ARGOCD_REPO_SECRET_NAME:-argocd-repo-gitea-gitops}"
GITEA_WAIT_TIMEOUT="${GITEA_WAIT_TIMEOUT:-300s}"
ARGOCD_WAIT_TIMEOUT="${ARGOCD_WAIT_TIMEOUT:-300s}"
ARGOCD_SERVER_DEPLOYMENT="${ARGOCD_SERVER_DEPLOYMENT:-${RELEASE_NAME}-argocd-server}"

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
  --kube-context <context>   Optional kube context
  -h, --help                 Show this help message
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
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

case "$PROFILE" in
  k3d|k3s) ;;
  *) echo "Missing or unsupported --profile. Use k3d or k3s." >&2; usage; exit 1 ;;
esac

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

push_gitops_repo() {
  local repo_dir="$1"
  local remote_url="$2"
  local askpass_script="$3"

  (
    cd "$repo_dir"
    git init -b "$GITOPS_REPO_BRANCH" >/dev/null
    git add .
    git -c user.name="$GITOPS_ROBOT_USERNAME" -c user.email="$GITOPS_ROBOT_EMAIL" commit -m "Bootstrap GitOps repo" >/dev/null
    git remote add origin "$remote_url"
    GIT_TERMINAL_PROMPT=0 \
    GIT_USERNAME="$GITOPS_ROBOT_USERNAME" \
    GIT_PASSWORD="$GITOPS_ROBOT_PASSWORD" \
    git -c core.askPass="$askpass_script" push --force origin "HEAD:${GITOPS_REPO_BRANCH}" >/dev/null
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
GITEA_BASE_URL="http://${GITEA_HOST}"
GITEA_API_URL="${GITEA_BASE_URL}/api/v1"

CONFIG_GITOPS_ROBOT_PASSWORD="${GITOPS_ROBOT_PASSWORD:-}"
if GITOPS_ROBOT_PASSWORD="$(read_secret_value "$GITOPS_SECRET_NAME" '{.data.GITOPS_ROBOT_PASSWORD}')"; then
  :
elif [[ -n "${CONFIG_GITOPS_ROBOT_PASSWORD}" ]]; then
  GITOPS_ROBOT_PASSWORD="${CONFIG_GITOPS_ROBOT_PASSWORD}"
else
  GITOPS_ROBOT_PASSWORD="$(generate_password)"
fi

step "Refreshing bootstrap-managed secrets before the GitOps handoff"
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
"${BOOTSTRAP_SECRETS_CMD[@]}"

step "Installing Argo CD through the existing Helm path"
INSTALL_CMD=(
  ./scripts/install.sh
  --profile "$PROFILE"
  --bootstrap-config "$BOOTSTRAP_CONFIG_PATH"
  --release-name "$RELEASE_NAME"
  --namespace "$NAMESPACE"
  --enable-service argo-cd
)
if [[ -n "$KUBECONFIG_PATH" ]]; then
  INSTALL_CMD+=(--kubeconfig "$KUBECONFIG_PATH")
fi
if [[ -n "$KUBE_CONTEXT" ]]; then
  INSTALL_CMD+=(--kube-context "$KUBE_CONTEXT")
fi
"${INSTALL_CMD[@]}"

step "Waiting for Gitea and Argo CD"
wait_for_gitea
wait_for_argocd
configure_argocd_admin_account "${ARGOCD_ADMIN_USER:-admin}" "${ARGOCD_ADMIN_PASSWORD:-}"

step "Creating or updating the GitOps robot user in Gitea"
ROBOT_USER_PAYLOAD="$(build_admin_user_payload "$GITOPS_ROBOT_USERNAME" "$GITOPS_ROBOT_EMAIL" "$GITOPS_ROBOT_PASSWORD")"
ROBOT_USER_STATUS="$(curl -sS -o /dev/null -w '%{http_code}' "${GITEA_API_URL}/users/${GITOPS_ROBOT_USERNAME}")"
case "$ROBOT_USER_STATUS" in
  200)
    step "GitOps robot user ${GITOPS_ROBOT_USERNAME} already exists; preserving existing credentials"
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
  curl -sS -u "${GITOPS_ROBOT_USERNAME}:${GITOPS_ROBOT_PASSWORD}" \
    -o /dev/null -w '%{http_code}' \
    "${GITEA_API_URL}/repos/${GITOPS_ROBOT_USERNAME}/${GITOPS_REPO_NAME}"
)"
if [[ "$REPO_STATUS" == "404" ]]; then
  REPO_PAYLOAD="$(build_repo_payload "$GITOPS_REPO_NAME" "$GITOPS_REPO_BRANCH" "$GITOPS_REPO_PRIVATE")"
  gitea_api_json POST "${GITEA_API_URL}/user/repos" "$GITOPS_ROBOT_USERNAME" "$GITOPS_ROBOT_PASSWORD" "$REPO_PAYLOAD" >/dev/null
elif [[ "$REPO_STATUS" != "200" ]]; then
  echo "Unexpected Gitea repo lookup status: ${REPO_STATUS}" >&2
  exit 1
fi

EXTERNAL_REPO_URL="${GITEA_BASE_URL}/${GITOPS_ROBOT_USERNAME}/${GITOPS_REPO_NAME}.git"
INTERNAL_REPO_URL="http://${RELEASE_NAME}-gitea-http.${NAMESPACE}.svc.cluster.local:3000/${GITOPS_ROBOT_USERNAME}/${GITOPS_REPO_NAME}.git"

step "Rendering and pushing the GitOps repo snapshot"
REPO_WORK_DIR="$(mktemp -d /tmp/ai-homebase-gitops-repo.XXXXXX)"
ASKPASS_SCRIPT="$(mktemp /tmp/ai-homebase-gitops-askpass.XXXXXX)"
ARGOCD_REPO_SECRET_MANIFEST="$(mktemp /tmp/ai-homebase-argocd-repo-secret.XXXXXX.yaml)"
trap 'rm -rf "$REPO_WORK_DIR" "$ASKPASS_SCRIPT" "$ARGOCD_REPO_SECRET_MANIFEST"' EXIT

cat >"$ASKPASS_SCRIPT" <<'SH'
#!/usr/bin/env bash
case "$1" in
  *Username*) printf '%s' "${GIT_USERNAME:?}" ;;
  *) printf '%s' "${GIT_PASSWORD:?}" ;;
esac
SH
chmod 0700 "$ASKPASS_SCRIPT"

python3 ./scripts/render-gitops-repo.py \
  --output-dir "$REPO_WORK_DIR" \
  --bootstrap-config "$BOOTSTRAP_CONFIG_PATH" \
  --profile "$PROFILE" \
  --cluster-name "$GITOPS_CLUSTER_NAME" \
  --release-name "$RELEASE_NAME" \
  --namespace "$NAMESPACE" \
  --repo-url "$INTERNAL_REPO_URL" \
  --repo-branch "$GITOPS_REPO_BRANCH" \
  --project "$GITOPS_PROJECT"

push_gitops_repo "$REPO_WORK_DIR" "$EXTERNAL_REPO_URL" "$ASKPASS_SCRIPT"

step "Persisting GitOps bootstrap credentials"
create_and_apply_secret "$GITOPS_SECRET_NAME" \
  --from-literal=GITOPS_ROBOT_USERNAME="$GITOPS_ROBOT_USERNAME" \
  --from-literal=GITOPS_ROBOT_EMAIL="$GITOPS_ROBOT_EMAIL" \
  --from-literal=GITOPS_ROBOT_PASSWORD="$GITOPS_ROBOT_PASSWORD" \
  --from-literal=GITOPS_REPO_NAME="$GITOPS_REPO_NAME" \
  --from-literal=GITOPS_REPO_BRANCH="$GITOPS_REPO_BRANCH" \
  --from-literal=GITOPS_PROJECT="$GITOPS_PROJECT"

step "Registering the GitOps repo in Argo CD"
build_repo_secret_manifest "$NAMESPACE" "$ARGOCD_REPO_SECRET_NAME" "$INTERNAL_REPO_URL" "$GITOPS_ROBOT_USERNAME" "$GITOPS_ROBOT_PASSWORD" \
  >"$ARGOCD_REPO_SECRET_MANIFEST"
kubectl "${KUBECTL_CONTEXT_ARGS[@]}" apply -f "$ARGOCD_REPO_SECRET_MANIFEST"

step "Applying the Argo CD project and applications"
kubectl "${KUBECTL_CONTEXT_ARGS[@]}" apply -f "${REPO_WORK_DIR}/gitops/clusters/${GITOPS_CLUSTER_NAME}/project.yaml"
kubectl "${KUBECTL_CONTEXT_ARGS[@]}" apply -f "${REPO_WORK_DIR}/gitops/clusters/${GITOPS_CLUSTER_NAME}/applications/platform-stack.yaml"
kubectl "${KUBECTL_CONTEXT_ARGS[@]}" apply -f "${REPO_WORK_DIR}/gitops/clusters/${GITOPS_CLUSTER_NAME}/root-application.yaml"

printf 'GitOps bootstrap complete.\n'
printf '  Argo CD URL: http://%s\n' "$ARGOCD_HOST"
printf '  Gitea GitOps repo: %s\n' "$EXTERNAL_REPO_URL"
printf '  Argo CD repository URL: %s\n' "$INTERNAL_REPO_URL"
printf '  Argo CD project: %s\n' "$GITOPS_PROJECT"
