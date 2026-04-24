#!/usr/bin/env bash
set -Eeuo pipefail

RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-}"
KUBE_CONTEXT="${KUBE_CONTEXT:-}"
OPENCLAW_DEPLOYMENT_NAME="${OPENCLAW_DEPLOYMENT_NAME:-${RELEASE_NAME}-openclaw}"
OPENCLAW_ROLLOUT_TIMEOUT="${OPENCLAW_ROLLOUT_TIMEOUT:-600s}"
OPENCLAW_SETUP_RETRIES="${OPENCLAW_SETUP_RETRIES:-3}"
OPENCLAW_SETUP_RETRY_DELAY_SECONDS="${OPENCLAW_SETUP_RETRY_DELAY_SECONDS:-15}"
PHASE="${PHASE:-post-gitops}"
OPENCLAW_CONTAINER_NAME="${OPENCLAW_CONTAINER_NAME:-openclaw}"

usage() {
  cat <<USAGE
Usage: $0 [options]

Seed idempotent bundled OpenClaw skill setup for the running gateway.

Options:
  --release-name <name>     Helm release name (default: ${RELEASE_NAME})
  --namespace <name>        Kubernetes namespace (default: ${NAMESPACE})
  --kubeconfig <path>       Optional kubeconfig path
  --kube-context <context>  Optional kube context
  --deployment <name>       OpenClaw deployment name (default: ${OPENCLAW_DEPLOYMENT_NAME})
  --container <name>        OpenClaw container name for kubectl exec (default: ${OPENCLAW_CONTAINER_NAME})
  --phase <name>            Validation phase: pre-gitops or post-gitops (default: ${PHASE})
  -h, --help                Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release-name) RELEASE_NAME="$2"; OPENCLAW_DEPLOYMENT_NAME="${2}-openclaw"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --kube-context) KUBE_CONTEXT="$2"; shift 2 ;;
    --deployment) OPENCLAW_DEPLOYMENT_NAME="$2"; shift 2 ;;
    --container) OPENCLAW_CONTAINER_NAME="$2"; shift 2 ;;
    --phase) PHASE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

case "$PHASE" in
  pre-gitops|post-gitops) ;;
  *)
    echo "Unsupported --phase: ${PHASE}. Use pre-gitops or post-gitops." >&2
    exit 1
    ;;
esac

KUBECTL_ARGS=()
if [[ -n "$KUBECONFIG_PATH" ]]; then
  KUBECTL_ARGS+=(--kubeconfig "$KUBECONFIG_PATH")
fi
if [[ -n "$KUBE_CONTEXT" ]]; then
  KUBECTL_ARGS+=(--context "$KUBE_CONTEXT")
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "Missing required dependency: kubectl" >&2
  exit 1
fi

wait_for_openclaw_rollout() {
  local output=""
  if output="$(kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" rollout status "deployment/${OPENCLAW_DEPLOYMENT_NAME}" --timeout "$OPENCLAW_ROLLOUT_TIMEOUT" 2>&1)"; then
    return 0
  fi
  printf '%s\n' "$output" >&2
  return 1
}

wait_for_openclaw_rollout

run_gateway_setup() {
  local label="$1"
  local script="$2"
  local attempt=1
  local status=0

  while (( attempt <= OPENCLAW_SETUP_RETRIES )); do
    echo "Checking OpenClaw skill setup: ${label} (attempt ${attempt}/${OPENCLAW_SETUP_RETRIES})"
    wait_for_openclaw_rollout
    if kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" exec -c "$OPENCLAW_CONTAINER_NAME" "deployment/${OPENCLAW_DEPLOYMENT_NAME}" -- env OPENCLAW_SETUP_PHASE="$PHASE" sh -lc "$script"; then
      return 0
    else
      status=$?
    fi

    if (( attempt == OPENCLAW_SETUP_RETRIES )); then
      break
    fi

    echo "OpenClaw setup check '${label}' failed with exit ${status}; waiting ${OPENCLAW_SETUP_RETRY_DELAY_SECONDS}s before retrying." >&2
    sleep "$OPENCLAW_SETUP_RETRY_DELAY_SECONDS"
    (( attempt += 1 ))
  done

  return "$status"
}

run_gateway_setup "github" '
set -eu
warn() { echo "Warning: github skill setup skipped: $*" >&2; }
if ! command -v gh >/dev/null 2>&1; then
  warn "gh CLI is not installed."
  exit 0
fi
if [ -z "${GITHUB_TOKEN:-}" ] && [ -z "${GH_TOKEN:-}" ]; then
  warn "GITHUB_TOKEN or GH_TOKEN is not present in the gateway environment."
  exit 0
fi
export GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if ! gh auth status >/dev/null 2>&1; then
  warn "gh auth status failed with the provided token."
  exit 0
fi
if ! openclaw skills info github >/dev/null 2>&1; then
  warn "openclaw github skill is not ready."
fi
'

run_gateway_setup "summarize" '
set -eu
warn() { echo "Warning: summarize skill setup skipped: $*" >&2; }
if ! command -v summarize >/dev/null 2>&1; then
  warn "summarize CLI is not installed."
  exit 0
fi
if [ -z "${OPENAI_API_KEY:-}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -z "${GEMINI_API_KEY:-}" ]; then
  warn "no supported summarization provider key is present."
  exit 0
fi
if ! openclaw skills info summarize >/dev/null 2>&1; then
  warn "openclaw summarize skill is not ready."
fi
'

run_gateway_setup "tmux" '
set -eu
warn() { echo "Warning: tmux skill setup skipped: $*" >&2; }
if ! command -v tmux >/dev/null 2>&1; then
  warn "tmux is not installed."
  exit 0
fi
if ! openclaw skills info tmux >/dev/null 2>&1; then
  warn "openclaw tmux skill is not ready."
fi
'

run_gateway_setup "reviewer-gitea" '
set -eu
warn() { echo "Warning: reviewer Gitea setup skipped: $*" >&2; }
setup_phase="${OPENCLAW_SETUP_PHASE:-post-gitops}"
check_tea_repo_access() {
  local label="$1"
  local login_name="$2"
  local repo_owner="${CODER_GITEA_USERNAME:-coder}"
  local repo_name="${CODER_GITOPS_REPO_NAME:-${GITOPS_REPO_NAME:-cluster-gitops}}"

  if ! tea repo view "${repo_owner}/${repo_name}" --login "${login_name}" >/dev/null 2>&1; then
    warn "tea repo view ${repo_owner}/${repo_name} failed for ${label} via login ${login_name}."
    return 1
  fi
}
seed_reviewer_home() {
  local workspace_home="$1"
  local label="$2"
  local login_name="$3"

  if ! env \
    HOME="${workspace_home}" \
    XDG_CONFIG_HOME="${workspace_home}/.config" \
    XDG_CACHE_HOME="${workspace_home}/.cache" \
    XDG_STATE_HOME="${workspace_home}/.local/state" \
    GIT_CONFIG_GLOBAL="${workspace_home}/.config/git/config" \
    reviewer-gitea-init.sh; then
    warn "${label} reviewer-gitea-init.sh failed."
    return 1
  fi

  if ! (
    export HOME="${workspace_home}"
    export XDG_CONFIG_HOME="${workspace_home}/.config"
    export XDG_CACHE_HOME="${workspace_home}/.cache"
    export XDG_STATE_HOME="${workspace_home}/.local/state"
    export GIT_CONFIG_GLOBAL="${workspace_home}/.config/git/config"
    check_tea_repo_access "${label}" "${login_name}"
  ); then
    return 1
  fi
}
if ! command -v reviewer-gitea-init.sh >/dev/null 2>&1; then
  warn "reviewer-gitea-init.sh is not installed."
  exit 0
fi
if ! command -v tea >/dev/null 2>&1; then
  warn "tea CLI is not installed."
  exit 0
fi
if [ -z "${REVIEWER_GITEA_BASE_URL:-}" ] || [ -z "${REVIEWER_GITEA_USERNAME:-}" ]; then
  warn "reviewer Gitea env vars are incomplete."
  exit 0
fi
if [ -z "${REVIEWER_GITEA_TOKEN:-}" ] && [ -z "${REVIEWER_GITEA_PASSWORD:-}" ]; then
  warn "reviewer Gitea setup needs REVIEWER_GITEA_TOKEN or REVIEWER_GITEA_PASSWORD."
  exit 0
fi
if [ "$setup_phase" = "pre-gitops" ]; then
  if [ -z "${REVIEWER_GITEA_BOOTSTRAP_URL:-}" ]; then
    warn "reviewer Gitea bootstrap URL is not present yet."
  fi
  exit 0
fi
if ! reviewer-gitea-init.sh; then
  warn "reviewer-gitea-init.sh failed."
  exit 1
fi
login_name="${REVIEWER_GITEA_TEA_LOGIN_NAME:-reviewer}"
if ! tea login list 2>/dev/null | grep -F "${login_name}" >/dev/null; then
  warn "reviewer tea login ${login_name} is still missing after init."
  exit 1
fi
if ! check_tea_repo_access "gateway reviewer home" "${login_name}"; then
  exit 1
fi
seed_reviewer_home "/home/node/.openclaw/workspace-architect/.home" "architect workspace" "${login_name}"
seed_reviewer_home "/home/node/.openclaw/workspace-auditor/.home" "auditor workspace" "${login_name}"
'

run_gateway_setup "coder-workspace" '
set -eu
warn() { echo "Warning: coder workspace setup skipped: $*" >&2; }
setup_phase="${OPENCLAW_SETUP_PHASE:-post-gitops}"
workspace_home="/home/node/.openclaw/workspace-coder/.home"
tea_config="${workspace_home}/.config/tea/config.yml"
codex_auth="${workspace_home}/.codex/auth.json"
docker_config="${workspace_home}/.docker/config.json"
soft_fail() {
  warn "$1"
  if [ "$setup_phase" = "post-gitops" ]; then
    exit 1
  fi
  exit 0
}

if ! command -v coder-workspace-init.sh >/dev/null 2>&1; then
  soft_fail "coder-workspace-init.sh is not installed."
fi
if [ -z "${CODER_GITEA_BASE_URL:-}" ] || [ -z "${CODER_GITEA_USERNAME:-}" ]; then
  soft_fail "coder Gitea env vars are incomplete."
fi
if [ -z "${OPENAI_API_KEY:-}" ]; then
  soft_fail "OPENAI_API_KEY is not present in the gateway environment."
fi
if [ -z "${CODER_GITEA_TOKEN:-}" ] && [ -z "${CODER_GITEA_PASSWORD:-}" ]; then
  soft_fail "coder workspace setup needs CODER_GITEA_TOKEN or CODER_GITEA_PASSWORD."
fi
if [ -z "${CODER_REGISTRY_PASSWORD:-}" ]; then
  soft_fail "CODER_REGISTRY_PASSWORD is not present in the gateway environment."
fi
if [ "$setup_phase" = "pre-gitops" ]; then
  exit 0
fi
if ! env \
  HOME="${workspace_home}" \
  CODEX_HOME="${workspace_home}/.codex" \
  XDG_CONFIG_HOME="${workspace_home}/.config" \
  XDG_CACHE_HOME="${workspace_home}/.cache" \
  XDG_STATE_HOME="${workspace_home}/.local/state" \
  DOCKER_CONFIG="${workspace_home}/.docker" \
  GIT_CONFIG_GLOBAL="${workspace_home}/.gitconfig" \
  coder-workspace-init.sh; then
  soft_fail "coder-workspace-init.sh failed."
fi
if [ ! -f "${codex_auth}" ]; then
  soft_fail "coder Codex auth file is still missing after init."
fi
if [ ! -f "${tea_config}" ]; then
  soft_fail "coder tea config is still missing after init."
fi
if ! grep -F "default: true" "${tea_config}" >/dev/null 2>&1; then
  warn "coder tea login is not marked default after init."
fi
if [ ! -f "${docker_config}" ]; then
  soft_fail "coder docker config is still missing after init."
fi
'
