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
  --every "15m" \
  --session isolated \
  --agent watchdog \
  --no-deliver \
  --message "Run heartbeat check. Verify the local OpenClaw gateway readiness endpoint responds at http://127.0.0.1:18789/readyz. Read the heartbeat file from Nextcloud at /Projects/ai-homebase/heartbeat.json and check main's last activity timestamp. Do NOT use sessions_send or sessions_list from this cron context; both are unreliable from sandboxed cron sessions and must not be treated as authoritative signals. If the gateway is healthy and main's heartbeat is within the last 30 minutes, append a short OK line to /Projects/ai-homebase/watchdog-status-log.md and do not escalate. If the gateway is down or the heartbeat is stale by more than 30 minutes, append a short failure note to the same status log. Require 2 consecutive failures before escalating beyond the log, and apply the severity gates from AGENTS.md before treating anything as warning or critical."

ensure_job "Watchdog platform sweep" \
  --name "Watchdog platform sweep" \
  --cron "15 */12 * * *" \
  --session isolated \
  --agent watchdog \
  --no-deliver \
  --message "Run platform sweep. Check the local OpenClaw gateway readiness endpoint, inspect recent session behavior with the session-logs skill when that helps confirm whether failures are transient or recurring, and inspect TLS expiry for the core ingress hosts you can reach from the gateway with openssl, including OpenClaw and the MCP endpoints. Do NOT use sessions_send or sessions_list from this cron context; they are unreliable here and must not be used as the escalation path. Summarize findings concisely and append the result to /Projects/ai-homebase/watchdog-status-log.md. If issues are found, write a clear warning or critical note to that Nextcloud status log and explicitly flag it for main to pick up from the log; the standing watchdog session can escalate via sessions_send later if main is available there. If everything is clear, append a one-line all-clear and do not escalate."

ensure_job "Archivist nightly grooming" \
  --name "Archivist nightly grooming" \
  --cron "30 2 * * *" \
  --session isolated \
  --agent archivist \
  --no-deliver \
  --message "Run nightly knowledge graph grooming. Review durable Qdrant memories that are new, weakly linked, or likely to deserve graph structure. Review relevant Nextcloud project material, especially /Projects/ai-homebase/knowledge-graph-schema.md and related cluster docs, for durable entities and relationships not yet represented in the graph. Use a Node.js Bolt connection with require('neo4j-driver') and reusable Cypher queries to add or update only canonical graph structure; do not rely on mgconsole. Use few, general-purpose labels and relationships, and do not proliferate domain-specific types when existing structure can carry the meaning. Keep Qdrant-linked graph nodes annotated with the Qdrant ID and provenance metadata. Summarize important schema or knowledge changes to session agent:main:main via sessions_send only when the changes matter for other agents or the user."

ensure_job "Watchdog daily digest" \
  --name "Watchdog daily digest" \
  --cron "0 7 * * *" \
  --session isolated \
  --agent watchdog \
  --no-deliver \
  --message "Run daily health digest. Read /Projects/ai-homebase/watchdog-status-log.md and summarize the last 24 hours of heartbeat and platform-sweep results. Read the budget ledger at /Projects/ai-homebase/budget-ledger.json and add a budget summary covering daily, weekly, and monthly spend per agent, flagging any agents that are approaching their thresholds. Include the budget summary alongside the existing health digest. Call out repeated failures, inability to reach main, or upcoming TLS expiry if present. Produce a concise daily report for main, send it to session agent:main:main via sessions_send with a [WATCHDOG OK] prefix when healthy or [WATCHDOG WARNING] when attention is needed, and append the digest summary to the same status log while trimming older material so the log stays focused on roughly the last 7 days."
