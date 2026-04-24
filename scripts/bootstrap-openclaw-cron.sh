#!/usr/bin/env bash
set -Eeuo pipefail

RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-}"
KUBE_CONTEXT="${KUBE_CONTEXT:-}"
OPENCLAW_DEPLOYMENT_NAME="${OPENCLAW_DEPLOYMENT_NAME:-${RELEASE_NAME}-openclaw}"
OPENCLAW_ROLLOUT_TIMEOUT="${OPENCLAW_ROLLOUT_TIMEOUT:-600s}"
OPENCLAW_USER_TIMEZONE="${OPENCLAW_USER_TIMEZONE:-Europe/Berlin}"
OPENCLAW_CONTAINER_NAME="${OPENCLAW_CONTAINER_NAME:-openclaw}"
VERBOSE=0

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
  --container <name>        OpenClaw container name for kubectl exec (default: ${OPENCLAW_CONTAINER_NAME})
  --user-timezone <tz>      IANA timezone for user-day cron jobs (default: ${OPENCLAW_USER_TIMEZONE})
  --verbose                 Stream full OpenClaw cron command output
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
    --user-timezone) OPENCLAW_USER_TIMEZONE="$2"; shift 2 ;;
    --verbose) VERBOSE=1; shift ;;
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

exec_in_openclaw_deployment() {
  kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" exec -c "$OPENCLAW_CONTAINER_NAME" "deployment/${OPENCLAW_DEPLOYMENT_NAME}" -- "$@"
}

bootstrap_cli_scope_upgrade_request_ids() {
  exec_in_openclaw_deployment sh -ceu '
state_dir="${OPENCLAW_STATE_DIR:-${OPENCLAW_HOME:-/home/node/.openclaw}}"
pending_file="${state_dir}/devices/pending.json"
[ -s "$pending_file" ] || exit 0
PENDING_FILE="$pending_file" python3 - <<'"'"'PY'"'"'
import json
import os
from pathlib import Path

pending_path = Path(os.environ["PENDING_FILE"])
try:
    payload = json.loads(pending_path.read_text())
except FileNotFoundError:
    raise SystemExit(0)

if not isinstance(payload, dict):
    raise SystemExit(0)

for request_id, request in payload.items():
    if not isinstance(request, dict):
        continue
    if request.get("clientId") != "cli":
        continue
    if request.get("clientMode") != "cli":
        continue
    if request.get("role") != "operator":
        continue
    print(request.get("requestId") or request_id)
PY
'
}

ensure_bootstrap_cli_write_scopes() {
  local request_ids=""
  local request_id=""
  local remaining_request_ids=""

  request_ids="$(bootstrap_cli_scope_upgrade_request_ids)"
  [[ -n "$request_ids" ]] || return 0

  while IFS= read -r request_id; do
    [[ -n "$request_id" ]] || continue
    echo "Approving OpenClaw bootstrap device request: ${request_id}"
    exec_in_openclaw_deployment openclaw devices approve "$request_id" >/dev/null
  done <<<"$request_ids"

  remaining_request_ids="$(bootstrap_cli_scope_upgrade_request_ids)"
  if [[ -n "$remaining_request_ids" ]]; then
    echo "OpenClaw bootstrap device approval is still pending for one or more CLI requests." >&2
    return 1
  fi
}

list_jobs_json() {
  exec_in_openclaw_deployment openclaw cron list --json
}

normalize_json_output() {
  python3 -c '
import json
import sys

raw = sys.stdin.read()
decoder = json.JSONDecoder()
for index, char in enumerate(raw):
    if char not in "[{":
        continue
    try:
        parsed, _ = decoder.raw_decode(raw[index:].lstrip())
    except json.JSONDecodeError:
        continue
    if isinstance(parsed, list):
        if all(isinstance(item, dict) for item in parsed):
            print(json.dumps(parsed))
            raise SystemExit(0)
        continue
    if isinstance(parsed, dict):
        jobs = parsed.get("jobs")
        if isinstance(jobs, list) and all(isinstance(item, dict) for item in jobs):
            print(json.dumps(parsed))
            raise SystemExit(0)

raise SystemExit("failed to locate cron JSON payload in command output")
'
}

job_exists() {
  local job_name="$1"
  local raw_json=""
  local normalized_json=""

  if ! raw_json="$(list_jobs_json 2>&1)"; then
    printf '%s\n' "$raw_json" >&2
    return 2
  fi
  normalized_json="$(printf '%s\n' "$raw_json" | normalize_json_output)"
  OPENCLAW_CRON_JOBS_JSON="$normalized_json" python3 - "$job_name" <<'PY'
import json
import os
import sys

target = sys.argv[1]
try:
    payload = json.loads(os.environ["OPENCLAW_CRON_JOBS_JSON"])
except json.JSONDecodeError as exc:
    raise SystemExit(f"invalid cron JSON payload: {exc}") from exc
jobs = payload if isinstance(payload, list) else payload.get("jobs", [])
for job in jobs:
    if not isinstance(job, dict):
        raise SystemExit("invalid cron JSON payload: job entry is not an object")
    if job.get("name") == target:
        raise SystemExit(0)
raise SystemExit(1)
PY
}

ensure_bootstrap_cli_write_scopes

ensure_job() {
  local job_name="$1"
  local output=""
  local exists_status=0
  shift
  if job_exists "$job_name"; then
    echo "OpenClaw cron job already present: ${job_name}"
    return 0
  else
    exists_status=$?
    if [[ "$exists_status" -ne 1 ]]; then
      return "$exists_status"
    fi
  fi

  echo "Creating OpenClaw cron job: ${job_name}"
  if output="$(exec_in_openclaw_deployment openclaw cron add "$@" 2>&1)"; then
    if [[ "$VERBOSE" -eq 1 && -n "$output" ]]; then
      printf '%s\n' "$output"
    fi
    return 0
  fi

  printf '%s\n' "$output" >&2
  return 1
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
  --session isolated \
  --agent archivist \
  --no-deliver \
  --message "$(read_message "archivist-weekly-graph-grooming.md")"

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
  --session isolated \
  --agent watchdog \
  --no-deliver \
  --message "$(read_message "watchdog-daily-wrap-up.md")"

ensure_job "Architect daily wrap-up" \
  --name "Architect daily wrap-up" \
  --cron "52 23 * * *" \
  --tz "$OPENCLAW_USER_TIMEZONE" \
  --session isolated \
  --agent architect \
  --no-deliver \
  --message "$(read_message "architect-daily-wrap-up.md")"

ensure_job "Archivist daily wrap-up" \
  --name "Archivist daily wrap-up" \
  --cron "54 23 * * *" \
  --tz "$OPENCLAW_USER_TIMEZONE" \
  --session isolated \
  --agent archivist \
  --no-deliver \
  --message "$(read_message "archivist-daily-wrap-up.md")"

ensure_job "Auditor daily wrap-up" \
  --name "Auditor daily wrap-up" \
  --cron "56 23 * * *" \
  --tz "$OPENCLAW_USER_TIMEZONE" \
  --session isolated \
  --agent auditor \
  --no-deliver \
  --message "$(read_message "auditor-daily-wrap-up.md")"

ensure_job "Main daily wrap-up" \
  --name "Main daily wrap-up" \
  --cron "58 23 * * *" \
  --tz "$OPENCLAW_USER_TIMEZONE" \
  --session main \
  --wake now \
  --agent main \
  --system-event "$(read_message "main-daily-wrap-up.md")"
