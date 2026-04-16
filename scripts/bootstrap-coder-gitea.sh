#!/usr/bin/env bash
set -Eeuo pipefail

BOOTSTRAP_CONFIG_PATH="${BOOTSTRAP_CONFIG_PATH:-bootstrap.local.toml}"
RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-}"
RAW_KUBECONFIG="${KUBECONFIG:-}"
GITEA_BOOTSTRAP_LOCAL_PORT="${GITEA_BOOTSTRAP_LOCAL_PORT:-13001}"
GITEA_PORT_FORWARD_PID=""
GITEA_PORT_FORWARD_LOG=""

usage() {
  cat <<USAGE
Usage: $0 [options]

Create or update the dedicated coder and reviewer Gitea users so the implementation and review agents can use git and tea immediately.

Options:
  --bootstrap-config <path>  Bootstrap config file (default: ${BOOTSTRAP_CONFIG_PATH})
  --release-name <name>      Helm release name (default: ${RELEASE_NAME})
  --namespace <name>         Kubernetes namespace (default: ${NAMESPACE})
  --kubeconfig <path>        Optional kubeconfig path
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
    --bootstrap-config) BOOTSTRAP_CONFIG_PATH="$2"; shift 2 ;;
    --release-name) RELEASE_NAME="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$KUBECONFIG_PATH" ]]; then
  KUBECONFIG_PATH="$(normalize_kubeconfig_path "$RAW_KUBECONFIG")"
fi

KUBECTL_ARGS=()
if [[ -n "$KUBECONFIG_PATH" ]]; then
  KUBECTL_ARGS=(--kubeconfig "$KUBECONFIG_PATH")
fi

cleanup() {
  if [[ -n "${GITEA_PORT_FORWARD_PID:-}" ]] && kill -0 "$GITEA_PORT_FORWARD_PID" >/dev/null 2>&1; then
    kill "$GITEA_PORT_FORWARD_PID" >/dev/null 2>&1 || true
    wait "$GITEA_PORT_FORWARD_PID" >/dev/null 2>&1 || true
  fi
  rm -f "${GITEA_PORT_FORWARD_LOG:-}" /tmp/coder-gitea-user.json /tmp/reviewer-gitea-user.json
}
trap cleanup EXIT

start_gitea_port_forward() {
  GITEA_PORT_FORWARD_LOG="$(mktemp /tmp/ai-homebase-coder-gitea-port-forward.XXXXXX.log)"
  kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" port-forward \
    "service/${RELEASE_NAME}-gitea-http" \
    "127.0.0.1:${GITEA_BOOTSTRAP_LOCAL_PORT}:3000" \
    >"$GITEA_PORT_FORWARD_LOG" 2>&1 &
  GITEA_PORT_FORWARD_PID=$!

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

eval "$(python3 ./scripts/bootstrap-config.py shell-vars --config "$BOOTSTRAP_CONFIG_PATH")"

if [[ -z "${CODER_GITEA_PASSWORD:-}" ]]; then
  CODER_GITEA_PASSWORD="$(kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" get secret coder-credentials -o jsonpath='{.data.CODER_GITEA_PASSWORD}' 2>/dev/null | base64 -d || true)"
fi
if [[ -z "${REVIEWER_GITEA_PASSWORD:-}" ]]; then
  REVIEWER_GITEA_PASSWORD="$(kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" get secret reviewer-credentials -o jsonpath='{.data.REVIEWER_GITEA_PASSWORD}' 2>/dev/null | base64 -d || true)"
fi

if [[ -z "${GITEA_HOST:-}" || -z "${CODER_GITEA_USERNAME:-}" || -z "${CODER_GITEA_PASSWORD:-}" || -z "${REVIEWER_GITEA_USERNAME:-}" || -z "${REVIEWER_GITEA_PASSWORD:-}" ]]; then
  echo "Skipping Gitea agent-user bootstrap because host or credentials are missing."
  exit 0
fi

admin_user="$(kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" get secret gitea-admin-secret -o jsonpath='{.data.username}' | base64 -d)"
admin_password="$(kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" get secret gitea-admin-secret -o jsonpath='{.data.password}' | base64 -d)"

start_gitea_port_forward
gitea_api_url="http://127.0.0.1:${GITEA_BOOTSTRAP_LOCAL_PORT}/api/v1"
for _ in {1..300}; do
  if curl -fsS "${gitea_api_url}/version" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
curl -fsS "${gitea_api_url}/version" >/dev/null

ensure_gitea_user() {
  local username="$1"
  local email="$2"
  local password="$3"
  local full_name="$4"
  local body_file="$5"
  local status
  local create_payload
  local edit_payload

  status="$(
    curl -sS -o "$body_file" -w '%{http_code}' \
      -u "${admin_user}:${admin_password}" \
      "${gitea_api_url}/users/${username}"
  )"

  create_payload="$(
    python3 - <<PY
import json
print(json.dumps({
    "username": ${username@Q},
    "email": ${email@Q},
    "password": ${password@Q},
    "must_change_password": False,
    "send_notify": False,
    "visibility": "private",
    "full_name": ${full_name@Q},
}))
PY
  )"

  edit_payload="$(
    python3 - <<PY
import json
print(json.dumps({
    "source_id": 0,
    "login_name": "",
    "email": ${email@Q},
    "password": ${password@Q},
    "must_change_password": False,
    "prohibit_login": False,
    "active": True,
    "visibility": "private",
    "full_name": ${full_name@Q},
}))
PY
  )"

  case "$status" in
    200)
      curl -sS -X PATCH \
        -u "${admin_user}:${admin_password}" \
        -H 'Content-Type: application/json' \
        -d "$edit_payload" \
        "${gitea_api_url}/admin/users/${username}" >/dev/null
      ;;
    404)
      curl -sS -X POST \
        -u "${admin_user}:${admin_password}" \
        -H 'Content-Type: application/json' \
        -d "$create_payload" \
        "${gitea_api_url}/admin/users" >/dev/null
      ;;
    *)
      echo "Unexpected Gitea user lookup status for ${username}: ${status}" >&2
      cat "$body_file" >&2 || true
      exit 1
      ;;
  esac
}

ensure_gitea_user "$CODER_GITEA_USERNAME" "$CODER_GITEA_EMAIL" "$CODER_GITEA_PASSWORD" "OpenClaw Coder" /tmp/coder-gitea-user.json
ensure_gitea_user "$REVIEWER_GITEA_USERNAME" "$REVIEWER_GITEA_EMAIL" "$REVIEWER_GITEA_PASSWORD" "OpenClaw Reviewer" /tmp/reviewer-gitea-user.json

echo "Coder Gitea user ${CODER_GITEA_USERNAME} is ready at http://${GITEA_HOST}."
echo "Reviewer Gitea user ${REVIEWER_GITEA_USERNAME} is ready at http://${GITEA_HOST}."
