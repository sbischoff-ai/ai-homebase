#!/usr/bin/env bash
set -Eeuo pipefail

BOOTSTRAP_CONFIG_PATH="${BOOTSTRAP_CONFIG_PATH:-bootstrap.local.toml}"
RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-}"
RAW_KUBECONFIG="${KUBECONFIG:-}"
GITEA_BOOTSTRAP_LOCAL_PORT="${GITEA_BOOTSTRAP_LOCAL_PORT:-13001}"
CODER_GITEA_TEA_TOKEN_NAME="${CODER_GITEA_TEA_TOKEN_NAME:-openclaw-coder-sandbox}"
REVIEWER_GITEA_TEA_TOKEN_NAME="${REVIEWER_GITEA_TEA_TOKEN_NAME:-openclaw-reviewer}"
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

create_and_apply_secret() {
  local secret_name="$1"
  shift
  local tmp_file
  tmp_file="$(mktemp)"
  kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" create secret generic "$secret_name" "$@" --dry-run=client -o yaml >"$tmp_file"
  kubectl "${KUBECTL_ARGS[@]}" apply -f "$tmp_file" >/dev/null
  rm -f "$tmp_file"
}

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
    --address 127.0.0.1 \
    "service/${RELEASE_NAME}-gitea-http" \
    "${GITEA_BOOTSTRAP_LOCAL_PORT}:3000" \
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
if [[ -z "${REGISTRY_PASSWORD:-}" ]]; then
  REGISTRY_PASSWORD="$(kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" get secret coder-credentials -o jsonpath='{.data.CODER_REGISTRY_PASSWORD}' 2>/dev/null | base64 -d || true)"
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
  local request_body_file=""
  local request_status=""

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
    "login_name": ${username@Q},
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
      request_body_file="$(mktemp /tmp/ai-homebase-gitea-user-update.XXXXXX.json)"
      request_status="$(
        curl -sS -o "$request_body_file" -w '%{http_code}' -X PATCH \
          -u "${admin_user}:${admin_password}" \
          -H 'Content-Type: application/json' \
          -d "$edit_payload" \
          "${gitea_api_url}/admin/users/${username}"
      )"
      if [[ "$request_status" != "200" ]]; then
        echo "Failed to update Gitea user ${username}: HTTP ${request_status}" >&2
        cat "$request_body_file" >&2 || true
        rm -f "$request_body_file"
        exit 1
      fi
      rm -f "$request_body_file"
      ;;
    404)
      request_body_file="$(mktemp /tmp/ai-homebase-gitea-user-create.XXXXXX.json)"
      request_status="$(
        curl -sS -o "$request_body_file" -w '%{http_code}' -X POST \
          -u "${admin_user}:${admin_password}" \
          -H 'Content-Type: application/json' \
          -d "$create_payload" \
          "${gitea_api_url}/admin/users"
      )"
      if [[ "$request_status" != "201" && "$request_status" != "200" ]]; then
        echo "Failed to create Gitea user ${username}: HTTP ${request_status}" >&2
        cat "$request_body_file" >&2 || true
        rm -f "$request_body_file"
        exit 1
      fi
      rm -f "$request_body_file"
      ;;
    *)
      echo "Unexpected Gitea user lookup status for ${username}: ${status}" >&2
      cat "$body_file" >&2 || true
      exit 1
      ;;
  esac
}

extract_gitea_token_ids() {
  local token_name="$1"
  python3 -c '
import json
import sys

token_name = sys.argv[1]
raw = sys.stdin.read().strip()
if not raw:
    raise SystemExit(0)
payload = json.loads(raw)
if not isinstance(payload, list):
    raise SystemExit(0)
for item in payload:
    if item.get("name") == token_name and item.get("id") is not None:
        print(item["id"])
' "$token_name"
}

extract_gitea_token_sha1() {
  python3 -c '
import json
import sys

raw = sys.stdin.read().strip()
if not raw:
    raise SystemExit(0)
payload = json.loads(raw)
if not isinstance(payload, dict):
    raise SystemExit(0)
token = payload.get("sha1")
if token:
    print(token)
'
}

build_token_payload() {
  local token_name="$1"
  python3 - "$token_name" <<'PY'
import json
import sys

print(json.dumps({"name": sys.argv[1], "scopes": ["all"]}))
PY
}

wait_for_gitea_user_auth() {
  local username="$1"
  local password="$2"
  local ready_url="${gitea_api_url}/users/${username}/tokens"
  local response_file=""
  local status=""
  local attempt=0

  response_file="$(mktemp /tmp/ai-homebase-gitea-auth-ready.XXXXXX.json)"
  while (( attempt < 30 )); do
    status="$(
      curl -sS -o "$response_file" -w '%{http_code}' \
        --user "${username}:${password}" \
        "${ready_url}"
    )"
    if [[ "$status" == "200" ]]; then
      rm -f "$response_file"
      return 0
    fi
    if [[ "$status" != "401" && "$status" != "404" && "$status" != "000" ]]; then
      echo "Gitea user auth for ${username} failed unexpectedly with HTTP ${status}" >&2
      cat "$response_file" >&2 || true
      rm -f "$response_file"
      exit 1
    fi
    attempt=$((attempt + 1))
    sleep 1
  done

  echo "Timed out waiting for Gitea user ${username} authentication to become ready." >&2
  cat "$response_file" >&2 || true
  rm -f "$response_file"
  exit 1
}

ensure_gitea_api_token() {
  local username="$1"
  local password="$2"
  local token_name="$3"
  local tokens_url="${gitea_api_url}/users/${username}/tokens"
  local existing_token_ids
  local duplicate_token_ids
  local list_body_file=""
  local token_payload
  local token
  local create_body_file=""
  local create_status=""
  local create_attempt=0

  wait_for_gitea_user_auth "$username" "$password"
  list_body_file="$(mktemp /tmp/ai-homebase-gitea-token-list.XXXXXX.json)"
  curl -fsS -u "${username}:${password}" -o "$list_body_file" "${tokens_url}"
  existing_token_ids="$(extract_gitea_token_ids "${token_name}" <"$list_body_file" || true)"
  rm -f "$list_body_file"
  if [[ -n "${existing_token_ids}" ]]; then
    while IFS= read -r token_id; do
      [[ -n "${token_id}" ]] || continue
      curl -fsS -X DELETE -u "${username}:${password}" "${tokens_url}/${token_id}" >/dev/null
    done <<<"${existing_token_ids}"
  fi

  token_payload="$(build_token_payload "${token_name}")"
  create_body_file="$(mktemp /tmp/ai-homebase-gitea-token-create.XXXXXX.json)"
  while (( create_attempt < 5 )); do
    token=""
    create_status="$(
      curl -sS -o "$create_body_file" -w '%{http_code}' \
        -u "${username}:${password}" \
        -H 'Content-Type: application/json' \
        -d "${token_payload}" \
        "${tokens_url}"
    )"
    if [[ "$create_status" == "201" || "$create_status" == "200" ]]; then
      token="$(extract_gitea_token_sha1 <"$create_body_file" || true)"
      if [[ -n "${token}" ]]; then
        break
      fi
      list_body_file="$(mktemp /tmp/ai-homebase-gitea-token-list.XXXXXX.json)"
      curl -fsS -u "${username}:${password}" -o "$list_body_file" "${tokens_url}"
      duplicate_token_ids="$(extract_gitea_token_ids "${token_name}" <"$list_body_file" || true)"
      rm -f "$list_body_file"
      if [[ -n "${duplicate_token_ids}" ]]; then
        while IFS= read -r token_id; do
          [[ -n "${token_id}" ]] || continue
          curl -fsS -X DELETE -u "${username}:${password}" "${tokens_url}/${token_id}" >/dev/null
        done <<<"${duplicate_token_ids}"
      fi
      create_attempt=$((create_attempt + 1))
      sleep 1
      continue
    fi
    if [[ "$create_status" == "400" ]] && grep -q 'access token name has been used already' "$create_body_file"; then
      list_body_file="$(mktemp /tmp/ai-homebase-gitea-token-list.XXXXXX.json)"
      curl -fsS -u "${username}:${password}" -o "$list_body_file" "${tokens_url}"
      duplicate_token_ids="$(extract_gitea_token_ids "${token_name}" <"$list_body_file" || true)"
      rm -f "$list_body_file"
      if [[ -n "${duplicate_token_ids}" ]]; then
        while IFS= read -r token_id; do
          [[ -n "${token_id}" ]] || continue
          curl -fsS -X DELETE -u "${username}:${password}" "${tokens_url}/${token_id}" >/dev/null
        done <<<"${duplicate_token_ids}"
      fi
      create_attempt=$((create_attempt + 1))
      sleep 1
      continue
    fi
    break
  done
  if [[ "$create_status" != "201" && "$create_status" != "200" ]]; then
    echo "Failed to create Gitea API token ${token_name} for ${username}: HTTP ${create_status}" >&2
    cat "$create_body_file" >&2 || true
    rm -f "$create_body_file"
    exit 1
  fi

  if [[ -z "${token}" ]]; then
    echo "Failed to create Gitea API token ${token_name} for ${username}: missing sha1 in successful response." >&2
    cat "$create_body_file" >&2 || true
    rm -f "$create_body_file"
    exit 1
  fi
  rm -f "$create_body_file"

  printf '%s' "${token}"
}

ensure_gitea_user "$CODER_GITEA_USERNAME" "$CODER_GITEA_EMAIL" "$CODER_GITEA_PASSWORD" "OpenClaw Coder" /tmp/coder-gitea-user.json
ensure_gitea_user "$REVIEWER_GITEA_USERNAME" "$REVIEWER_GITEA_EMAIL" "$REVIEWER_GITEA_PASSWORD" "OpenClaw Reviewer" /tmp/reviewer-gitea-user.json

coder_gitea_token="$(ensure_gitea_api_token "$CODER_GITEA_USERNAME" "$CODER_GITEA_PASSWORD" "$CODER_GITEA_TEA_TOKEN_NAME")"
reviewer_gitea_token="$(ensure_gitea_api_token "$REVIEWER_GITEA_USERNAME" "$REVIEWER_GITEA_PASSWORD" "$REVIEWER_GITEA_TEA_TOKEN_NAME")"

create_and_apply_secret coder-credentials \
  --from-literal=CODER_GITEA_PASSWORD="${CODER_GITEA_PASSWORD}" \
  --from-literal=CODER_GITEA_TOKEN="${coder_gitea_token}" \
  --from-literal=CODER_REGISTRY_PASSWORD="${REGISTRY_PASSWORD:-}"
create_and_apply_secret reviewer-credentials \
  --from-literal=REVIEWER_GITEA_PASSWORD="${REVIEWER_GITEA_PASSWORD}" \
  --from-literal=REVIEWER_GITEA_TOKEN="${reviewer_gitea_token}"

echo "Coder Gitea user ${CODER_GITEA_USERNAME} is ready at http://${GITEA_HOST}."
echo "Reviewer Gitea user ${REVIEWER_GITEA_USERNAME} is ready at http://${GITEA_HOST}."
