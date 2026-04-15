#!/usr/bin/env bash
set -Eeuo pipefail

RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-}"
KUBE_CONTEXT="${KUBE_CONTEXT:-}"
OPENCLAW_DEPLOYMENT_NAME="${OPENCLAW_DEPLOYMENT_NAME:-${RELEASE_NAME}-openclaw}"
OPENCLAW_ROLLOUT_TIMEOUT="${OPENCLAW_ROLLOUT_TIMEOUT:-600s}"
OPENCLAW_USER_TIMEZONE="${OPENCLAW_USER_TIMEZONE:-Europe/Berlin}"

usage() {
  cat <<USAGE
Usage: $0 [options]

Seed the documented default OpenClaw cron jobs into the running gateway.

Options:
  --release-name <name>     Helm release name (default: ${RELEASE_NAME})
  --namespace <name>        Kubernetes namespace (default: ${NAMESPACE})
  --kubeconfig <path>       Optional kubeconfig path
  --kube-context <context>  Optional kube context
  --deployment <name>       OpenClaw deployment name (default: ${OPENCLAW_DEPLOYMENT_NAME})
  --user-timezone <tz>      IANA timezone for user-day cron jobs (default: ${OPENCLAW_USER_TIMEZONE})
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
    --user-timezone) OPENCLAW_USER_TIMEZONE="$2"; shift 2 ;;
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

for cmd in kubectl python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required dependency: ${cmd}" >&2
    exit 1
  fi
done

kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" rollout status "deployment/${OPENCLAW_DEPLOYMENT_NAME}" --timeout "$OPENCLAW_ROLLOUT_TIMEOUT"

list_jobs_json() {
  kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" exec "deployment/${OPENCLAW_DEPLOYMENT_NAME}" -- openclaw cron list --json
}

normalize_json_output() {
  python3 -c '
import sys

raw = sys.stdin.read()
start = None
for index, char in enumerate(raw):
    if char in "[{":
        start = index
        break
if start is None:
    raise SystemExit("failed to locate JSON payload in command output")
print(raw[start:].strip())
'
}

job_exists() {
  local job_name="$1"
  local normalized_json=""
  normalized_json="$(list_jobs_json | normalize_json_output)"
  OPENCLAW_CRON_JOBS_JSON="$normalized_json" python3 - "$job_name" <<'PY'
import json
import os
import sys

target = sys.argv[1]
payload = json.loads(os.environ["OPENCLAW_CRON_JOBS_JSON"])
jobs = payload if isinstance(payload, list) else payload.get("jobs", [])
for job in jobs:
    if job.get("name") == target:
        raise SystemExit(0)
raise SystemExit(1)
PY
}

ensure_job() {
  local job_name="$1"
  shift
  if job_exists "$job_name"; then
    echo "OpenClaw cron job already present: ${job_name}"
    return 0
  fi

  echo "Creating OpenClaw cron job: ${job_name}"
  kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" exec "deployment/${OPENCLAW_DEPLOYMENT_NAME}" -- openclaw cron add "$@"
}

read_message() {
  local msg_file
  msg_file="$(dirname "$0")/cron-messages/$1"
  if [[ ! -f "$msg_file" ]]; then
    echo "Missing cron message file: ${msg_file}" >&2
    exit 1
  fi
  cat "$msg_file"
}

ensure_job "Watchdog platform sweep" \
  --name "Watchdog platform sweep" \
  --cron "15 */12 * * *" \
  --session isolated \
  --agent watchdog \
  --no-deliver \
  --message "$(read_message "watchdog-platform-sweep.md")"

ensure_job "Watchdog nightly activity check" \
  --name "Watchdog nightly activity check" \
  --cron "30 2 * * *" \
  --session isolated \
  --agent watchdog \
  --no-deliver \
  --message "$(read_message "watchdog-nightly-activity-check.md")"

ensure_job "Watchdog daily digest" \
  --name "Watchdog daily digest" \
  --cron "0 7 * * *" \
  --session isolated \
  --agent watchdog \
  --no-deliver \
  --message "$(read_message "watchdog-daily-digest.md")"

ensure_job "Archivist weekly graph grooming" \
  --name "Archivist weekly graph grooming" \
  --cron "0 1 * * 0" \
  --session main \
  --wake now \
  --agent archivist \
  --system-event "$(read_message "archivist-weekly-graph-grooming.md")"

ensure_job "Auditor weekly review" \
  --name "Auditor weekly review" \
  --cron "0 3 * * 0" \
  --session isolated \
  --agent auditor \
  --no-deliver \
  --message "$(read_message "auditor-weekly-review.md")"

ensure_job "Watchdog daily wrap-up" \
  --name "Watchdog daily wrap-up" \
  --cron "50 23 * * *" \
  --tz "$OPENCLAW_USER_TIMEZONE" \
  --session main \
  --wake now \
  --agent watchdog \
  --system-event "$(read_message "watchdog-daily-wrap-up.md")"

ensure_job "Architect daily wrap-up" \
  --name "Architect daily wrap-up" \
  --cron "52 23 * * *" \
  --tz "$OPENCLAW_USER_TIMEZONE" \
  --session main \
  --wake now \
  --agent architect \
  --system-event "$(read_message "architect-daily-wrap-up.md")"

ensure_job "Archivist daily wrap-up" \
  --name "Archivist daily wrap-up" \
  --cron "54 23 * * *" \
  --tz "$OPENCLAW_USER_TIMEZONE" \
  --session main \
  --wake now \
  --agent archivist \
  --system-event "$(read_message "archivist-daily-wrap-up.md")"

ensure_job "Auditor daily wrap-up" \
  --name "Auditor daily wrap-up" \
  --cron "56 23 * * *" \
  --tz "$OPENCLAW_USER_TIMEZONE" \
  --session main \
  --wake now \
  --agent auditor \
  --system-event "$(read_message "auditor-daily-wrap-up.md")"

ensure_job "Main daily wrap-up" \
  --name "Main daily wrap-up" \
  --cron "58 23 * * *" \
  --tz "$OPENCLAW_USER_TIMEZONE" \
  --session main \
  --wake now \
  --agent main \
  --system-event "$(read_message "main-daily-wrap-up.md")"
