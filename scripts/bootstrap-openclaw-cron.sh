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

Seed the documented default OpenClaw cron jobs into the running gateway.

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

ensure_job "Watchdog heartbeat" \
  --name "Watchdog heartbeat" \
  --every "5m" \
  --session isolated \
  --agent watchdog \
  --no-deliver \
  --message "Run heartbeat check. Verify the local OpenClaw gateway readiness endpoint responds at http://127.0.0.1:18789/readyz. Confirm the standing main sessions exist and accept a brief ping for agents main, architect, coder, archivist, and watchdog. Use the status log at /Projects/ai-homebase/watchdog-status-log.md to determine whether this is a repeated failure; require at least 2 consecutive heartbeat failures before escalating as CRITICAL. If all checks are healthy, append a short OK line to the status log and stay quiet. If a check fails, append a short failure note to the status log when possible and send a concise alert to session agent:main:main via sessions_send with a [WATCHDOG WARNING] prefix for the first failure or a [WATCHDOG CRITICAL] prefix once the same heartbeat path has failed twice in a row."

ensure_job "Watchdog platform sweep" \
  --name "Watchdog platform sweep" \
  --cron "15 */6 * * *" \
  --session isolated \
  --agent watchdog \
  --no-deliver \
  --message "Run platform sweep. Check the local OpenClaw gateway readiness endpoint, confirm the standing main sessions for main, architect, coder, archivist, and watchdog still exist and respond, inspect recent session behavior with the session-logs skill when that helps confirm whether failures are transient or recurring, and inspect TLS expiry for the core ingress hosts you can reach from the gateway with openssl, including OpenClaw and the MCP endpoints. Summarize findings concisely, append the result to /Projects/ai-homebase/watchdog-status-log.md, and send a short report to session agent:main:main via sessions_send with [WATCHDOG WARNING] or [WATCHDOG CRITICAL] when issues are found. If everything is clear, append a one-line all-clear and do not escalate."

ensure_job "Archivist nightly grooming" \
  --name "Archivist nightly grooming" \
  --cron "30 2 * * *" \
  --session isolated \
  --agent archivist \
  --no-deliver \
  --message "Run nightly knowledge graph grooming. Review durable Qdrant memories that are new, weakly linked, or likely to deserve graph structure. Review relevant Nextcloud project material, especially /Projects/ai-homebase/knowledge-graph-schema.md and related cluster docs, for durable entities and relationships not yet represented in Memgraph. Use mgconsole and reusable Cypher queries to add or update only canonical graph structure, preferring existing labels and relationship types over inventing new ones. Keep Qdrant-linked graph nodes annotated with the Qdrant ID and provenance metadata. Summarize important schema or knowledge changes to session agent:main:main via sessions_send only when the changes matter for other agents or the user."

ensure_job "Watchdog daily digest" \
  --name "Watchdog daily digest" \
  --cron "0 7 * * *" \
  --session isolated \
  --agent watchdog \
  --no-deliver \
  --message "Run daily health digest. Read /Projects/ai-homebase/watchdog-status-log.md and summarize the last 24 hours of heartbeat and platform-sweep results. Call out repeated failures, inability to reach main, or upcoming TLS expiry if present. Produce a concise daily report for main, send it to session agent:main:main via sessions_send with a [WATCHDOG OK] prefix when healthy or [WATCHDOG WARNING] when attention is needed, and append the digest summary to the same status log while trimming older material so the log stays focused on roughly the last 7 days."
