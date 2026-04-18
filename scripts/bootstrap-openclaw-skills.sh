#!/usr/bin/env bash
set -Eeuo pipefail

RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-}"
KUBE_CONTEXT="${KUBE_CONTEXT:-}"
OPENCLAW_DEPLOYMENT_NAME="${OPENCLAW_DEPLOYMENT_NAME:-${RELEASE_NAME}-openclaw}"
OPENCLAW_ROLLOUT_TIMEOUT="${OPENCLAW_ROLLOUT_TIMEOUT:-600s}"

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
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

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

kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" rollout status "deployment/${OPENCLAW_DEPLOYMENT_NAME}" --timeout "$OPENCLAW_ROLLOUT_TIMEOUT"

run_gateway_setup() {
  local label="$1"
  local script="$2"
  echo "Checking OpenClaw skill setup: ${label}"
  kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" exec "deployment/${OPENCLAW_DEPLOYMENT_NAME}" -- sh -lc "$script"
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
if ! openclaw skills info github >/dev/null; then
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
if ! openclaw skills info summarize >/dev/null; then
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
if ! openclaw skills info tmux >/dev/null; then
  warn "openclaw tmux skill is not ready."
fi
'

run_gateway_setup "reviewer-gitea" '
set -eu
warn() { echo "Warning: reviewer Gitea setup skipped: $*" >&2; }
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
if ! reviewer-gitea-init.sh; then
  warn "reviewer-gitea-init.sh failed."
fi
login_name="${REVIEWER_GITEA_TEA_LOGIN_NAME:-reviewer}"
if ! tea login list 2>/dev/null | grep -F "${login_name}" >/dev/null; then
  warn "reviewer tea login ${login_name} is still missing after init."
  exit 0
fi
if ! tea repo list --login "${login_name}" >/dev/null 2>&1; then
  warn "tea repo list failed for login ${login_name}."
fi
'
