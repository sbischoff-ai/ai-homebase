#!/usr/bin/env bash
set -euo pipefail

warn() {
  echo >&2 "WARNING: $*"
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
  local ready_url="${CODER_GITEA_BOOTSTRAP_URL}/api/v1/users/${CODER_GITEA_USERNAME}/tokens"
  local response_file=""
  local status=""
  local attempt=0

  response_file="$(mktemp /tmp/openclaw-coder-gitea-auth-ready.XXXXXX.json)"
  while (( attempt < 30 )); do
    status="$(
      curl -sS -o "$response_file" -w '%{http_code}' \
        --user "${CODER_GITEA_USERNAME}:${CODER_GITEA_PASSWORD}" \
        "${ready_url}"
    )"
    if [[ "$status" == "200" ]]; then
      rm -f "$response_file"
      return 0
    fi
    if [[ "$status" != "401" && "$status" != "404" && "$status" != "000" ]]; then
      warn "Gitea user auth for ${CODER_GITEA_USERNAME} failed unexpectedly with HTTP ${status}."
      cat "$response_file" >&2 || true
      rm -f "$response_file"
      return 1
    fi
    attempt=$((attempt + 1))
    sleep 1
  done

  warn "Timed out waiting for Gitea user ${CODER_GITEA_USERNAME} authentication to become ready."
  cat "$response_file" >&2 || true
  rm -f "$response_file"
  return 1
}

ensure_coder_gitea_token() {
  local tokens_url="${CODER_GITEA_BOOTSTRAP_URL}/api/v1/users/${CODER_GITEA_USERNAME}/tokens"
  local existing_token_ids=""
  local duplicate_token_ids=""
  local list_body_file=""
  local token_payload=""
  local token=""
  local create_body_file=""
  local create_status=""
  local create_attempt=0

  if ! wait_for_gitea_user_auth; then
    return 1
  fi

  list_body_file="$(mktemp /tmp/openclaw-coder-gitea-token-list.XXXXXX.json)"
  if ! curl -fsS -u "${CODER_GITEA_USERNAME}:${CODER_GITEA_PASSWORD}" -o "$list_body_file" "${tokens_url}"; then
    warn "Failed to list existing coder Gitea tokens."
    rm -f "$list_body_file"
    return 1
  fi
  existing_token_ids="$(extract_gitea_token_ids "${CODER_GITEA_TEA_TOKEN_NAME}" <"$list_body_file" || true)"
  rm -f "$list_body_file"
  if [[ -n "${existing_token_ids}" ]]; then
    while IFS= read -r token_id; do
      [[ -n "${token_id}" ]] || continue
      curl -fsS -X DELETE -u "${CODER_GITEA_USERNAME}:${CODER_GITEA_PASSWORD}" "${tokens_url}/${token_id}" >/dev/null || true
    done <<<"${existing_token_ids}"
  fi

  token_payload="$(build_token_payload "${CODER_GITEA_TEA_TOKEN_NAME}")"
  create_body_file="$(mktemp /tmp/openclaw-coder-gitea-token-create.XXXXXX.json)"
  while (( create_attempt < 5 )); do
    token=""
    create_status="$(
      curl -sS -o "$create_body_file" -w '%{http_code}' \
        -u "${CODER_GITEA_USERNAME}:${CODER_GITEA_PASSWORD}" \
        -H 'Content-Type: application/json' \
        -d "${token_payload}" \
        "${tokens_url}"
    )"
    if [[ "$create_status" == "201" || "$create_status" == "200" ]]; then
      token="$(extract_gitea_token_sha1 <"$create_body_file" || true)"
      if [[ -n "${token}" ]]; then
        rm -f "$create_body_file"
        printf '%s\n' "$token"
        return 0
      fi
      list_body_file="$(mktemp /tmp/openclaw-coder-gitea-token-list.XXXXXX.json)"
      curl -fsS -u "${CODER_GITEA_USERNAME}:${CODER_GITEA_PASSWORD}" -o "$list_body_file" "${tokens_url}"
      duplicate_token_ids="$(extract_gitea_token_ids "${CODER_GITEA_TEA_TOKEN_NAME}" <"$list_body_file" || true)"
      rm -f "$list_body_file"
      if [[ -n "${duplicate_token_ids}" ]]; then
        while IFS= read -r token_id; do
          [[ -n "${token_id}" ]] || continue
          curl -fsS -X DELETE -u "${CODER_GITEA_USERNAME}:${CODER_GITEA_PASSWORD}" "${tokens_url}/${token_id}" >/dev/null || true
        done <<<"${duplicate_token_ids}"
      fi
      create_attempt=$((create_attempt + 1))
      sleep 1
      continue
    fi
    if [[ "$create_status" == "400" ]] && grep -q 'access token name has been used already' "$create_body_file"; then
      list_body_file="$(mktemp /tmp/openclaw-coder-gitea-token-list.XXXXXX.json)"
      curl -fsS -u "${CODER_GITEA_USERNAME}:${CODER_GITEA_PASSWORD}" -o "$list_body_file" "${tokens_url}"
      duplicate_token_ids="$(extract_gitea_token_ids "${CODER_GITEA_TEA_TOKEN_NAME}" <"$list_body_file" || true)"
      rm -f "$list_body_file"
      if [[ -n "${duplicate_token_ids}" ]]; then
        while IFS= read -r token_id; do
          [[ -n "${token_id}" ]] || continue
          curl -fsS -X DELETE -u "${CODER_GITEA_USERNAME}:${CODER_GITEA_PASSWORD}" "${tokens_url}/${token_id}" >/dev/null || true
        done <<<"${duplicate_token_ids}"
      fi
      create_attempt=$((create_attempt + 1))
      sleep 1
      continue
    fi
    break
  done

  if [[ "$create_status" != "201" && "$create_status" != "200" ]]; then
    warn "Failed to create Gitea token ${CODER_GITEA_TEA_TOKEN_NAME} for ${CODER_GITEA_USERNAME} (HTTP ${create_status})."
    cat "$create_body_file" >&2 || true
    rm -f "$create_body_file"
    return 1
  fi

  warn "Created Gitea token payload for ${CODER_GITEA_USERNAME} did not include a sha1 value."
  cat "$create_body_file" >&2 || true
  rm -f "$create_body_file"
  return 1
}

HOME_DIR="${HOME:-/home/node/.openclaw/workspace-coder/.home}"
CODEX_HOME_DIR="${CODEX_HOME:-${HOME_DIR}/.codex}"
XDG_CONFIG_HOME_DIR="${XDG_CONFIG_HOME:-${HOME_DIR}/.config}"
XDG_CACHE_HOME_DIR="${XDG_CACHE_HOME:-${HOME_DIR}/.cache}"
XDG_STATE_HOME_DIR="${XDG_STATE_HOME:-${HOME_DIR}/.local/state}"
DOCKER_CONFIG_DIR="${DOCKER_CONFIG:-${HOME_DIR}/.docker}"
GIT_CONFIG_GLOBAL_FILE="${GIT_CONFIG_GLOBAL:-${HOME_DIR}/.gitconfig}"

CODER_GITEA_USERNAME="${CODER_GITEA_USERNAME:-coder}"
CODER_GITEA_EMAIL="${CODER_GITEA_EMAIL:-coder@example.invalid}"
CODER_GITEA_HOST="${CODER_GITEA_HOST:-}"
CODER_GITEA_BASE_URL="${CODER_GITEA_BASE_URL:-}"
CODER_GITEA_BOOTSTRAP_URL="${CODER_GITEA_BOOTSTRAP_URL:-${CODER_GITEA_BASE_URL}}"
CODER_GITEA_TEA_URL="${CODER_GITEA_TEA_URL:-}"
CODER_GITEA_PASSWORD="${CODER_GITEA_PASSWORD:-}"
CODER_GITEA_TOKEN="${CODER_GITEA_TOKEN:-}"
CODER_GITEA_TEA_LOGIN_NAME="${CODER_GITEA_TEA_LOGIN_NAME:-coder}"
CODER_GITEA_TEA_TOKEN_NAME="${CODER_GITEA_TEA_TOKEN_NAME:-openclaw-coder-sandbox}"

CODER_REGISTRY_HOST="${CODER_REGISTRY_HOST:-}"
CODER_REGISTRY_USERNAME="${CODER_REGISTRY_USERNAME:-}"
CODER_REGISTRY_PASSWORD="${CODER_REGISTRY_PASSWORD:-}"

export HOME="${HOME_DIR}"
export CODEX_HOME="${CODEX_HOME_DIR}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME_DIR}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME_DIR}"
export XDG_STATE_HOME="${XDG_STATE_HOME_DIR}"
export DOCKER_CONFIG="${DOCKER_CONFIG_DIR}"
export GIT_CONFIG_GLOBAL="${GIT_CONFIG_GLOBAL_FILE}"

tea_ssh_host() {
  if [ -n "${CODER_GITEA_HOST}" ]; then
    printf '%s\n' "${CODER_GITEA_HOST}"
    return
  fi

  local host="${CODER_GITEA_TEA_URL:-${CODER_GITEA_BASE_URL}}"
  host="${host#*://}"
  host="${host%%/*}"
  host="${host%%:*}"
  printf '%s\n' "${host}"
}

write_tea_config() {
  local ssh_host created_at
  ssh_host="$(tea_ssh_host)"
  created_at="$(date +%s)"

  cat > "${XDG_CONFIG_HOME}/tea/config.yml" <<EOF
logins:
- name: ${CODER_GITEA_TEA_LOGIN_NAME}
  url: ${CODER_GITEA_TEA_URL}
  token: ${CODER_GITEA_TOKEN}
  default: true
  ssh_host: ${ssh_host}
  ssh_key: ""
  insecure: false
  user: ${CODER_GITEA_USERNAME}
  created: ${created_at}
preferences:
  editor: false
  flag_defaults:
    remote: ""
EOF
  chmod 0600 "${XDG_CONFIG_HOME}/tea/config.yml"
}

write_docker_config() {
  local auth
  auth="$(printf '%s:%s' "${CODER_REGISTRY_USERNAME}" "${CODER_REGISTRY_PASSWORD}" | base64 | tr -d '\n')"

  jq -n \
    --arg host "${CODER_REGISTRY_HOST}" \
    --arg username "${CODER_REGISTRY_USERNAME}" \
    --arg password "${CODER_REGISTRY_PASSWORD}" \
    --arg auth "${auth}" \
    '{
      auths: {
        ($host): {
          username: $username,
          password: $password,
          auth: $auth,
        }
      }
    }' > "${DOCKER_CONFIG}/config.json"
  chmod 0600 "${DOCKER_CONFIG}/config.json"
}

mkdir -p \
  "${CODEX_HOME}" \
  "${XDG_CONFIG_HOME}/tea" \
  "${XDG_CACHE_HOME}" \
  "${XDG_STATE_HOME}" \
  "${DOCKER_CONFIG}"

CODEX_DEFAULT_MODEL="${CODEX_DEFAULT_MODEL:-gpt-5.3-codex}"
CODEX_ELEVATED_MODEL="${CODEX_ELEVATED_MODEL:-gpt-5.5}"

cat > "${CODEX_HOME}/config.toml" <<EOF
# Codex CLI configuration for ai-homebase coder agent
# Generated by coder-workspace-init.sh
#
# This deployment uses gpt-5.3-codex by default for implementation work.
# The openclaw-codex-run helper can select ${CODEX_ELEVATED_MODEL} for
# unusually complex tasks with --elevated.
# The sandbox container is already Docker-isolated, so Codex itself runs
# without an extra inner sandbox or approval gate.
approval_policy = "never"
sandbox_mode = "danger-full-access"
model = "${CODEX_DEFAULT_MODEL}"
forced_login_method = "api"
EOF

if [ -n "${OPENAI_API_KEY:-}" ]; then
  jq -n --arg api_key "${OPENAI_API_KEY}" '{
    auth_mode: "apikey",
    OPENAI_API_KEY: $api_key,
  }' > "${CODEX_HOME}/auth.json"
  chmod 0600 "${CODEX_HOME}/auth.json"
else
  warn "OPENAI_API_KEY is unset; leaving coder workspace without seeded Codex auth"
fi

git config --global user.name "${CODER_GITEA_USERNAME}"
git config --global user.email "${CODER_GITEA_EMAIL}"

if [ -n "${CODER_GITEA_HOST}" ] && [ -n "${CODER_GITEA_PASSWORD}" ]; then
  cat > "${HOME}/.netrc" <<EOF
machine ${CODER_GITEA_HOST}
  login ${CODER_GITEA_USERNAME}
  password ${CODER_GITEA_PASSWORD}
EOF
  chmod 0600 "${HOME}/.netrc"
fi

if [ -z "${CODER_GITEA_BASE_URL}" ] && [ -n "${CODER_GITEA_HOST}" ]; then
  case "${CODER_GITEA_HOST}" in
    *.localtest.me) CODER_GITEA_BASE_URL="http://${CODER_GITEA_HOST}" ;;
    *) CODER_GITEA_BASE_URL="https://${CODER_GITEA_HOST}" ;;
  esac
fi

if [ -z "${CODER_GITEA_TEA_URL}" ]; then
  CODER_GITEA_TEA_URL="${CODER_GITEA_BASE_URL}"
fi

if [ -z "${CODER_GITEA_TOKEN}" ] && [ -n "${CODER_GITEA_BOOTSTRAP_URL}" ] && [ -n "${CODER_GITEA_USERNAME}" ] && [ -n "${CODER_GITEA_PASSWORD}" ]; then
  CODER_GITEA_TOKEN="$(ensure_coder_gitea_token || true)"
fi

if [ -n "${CODER_GITEA_TEA_URL}" ] && [ -n "${CODER_GITEA_TOKEN}" ]; then
  write_tea_config
else
  warn "coder Gitea token is unavailable; leaving coder workspace without seeded tea login"
fi

if [ -n "${CODER_REGISTRY_HOST}" ] && [ -n "${CODER_REGISTRY_USERNAME}" ] && [ -n "${CODER_REGISTRY_PASSWORD}" ]; then
  write_docker_config
else
  warn "coder registry credentials are unavailable; leaving coder workspace without registry auth"
fi
