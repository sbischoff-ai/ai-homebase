#!/usr/bin/env bash
set -euo pipefail

HOME_DIR="${HOME:-/home/node}"
XDG_CONFIG_HOME_DIR="${XDG_CONFIG_HOME:-${HOME_DIR}/.config}"
XDG_CACHE_HOME_DIR="${XDG_CACHE_HOME:-${HOME_DIR}/.cache}"
XDG_STATE_HOME_DIR="${XDG_STATE_HOME:-${HOME_DIR}/.local/state}"
GIT_CONFIG_GLOBAL_FILE="${GIT_CONFIG_GLOBAL:-${XDG_CONFIG_HOME_DIR}/git/config}"

REVIEWER_GITEA_USERNAME="${REVIEWER_GITEA_USERNAME:-reviewer}"
REVIEWER_GITEA_EMAIL="${REVIEWER_GITEA_EMAIL:-reviewer@example.invalid}"
REVIEWER_GITEA_HOST="${REVIEWER_GITEA_HOST:-}"
REVIEWER_GITEA_BASE_URL="${REVIEWER_GITEA_BASE_URL:-}"
REVIEWER_GITEA_BOOTSTRAP_URL="${REVIEWER_GITEA_BOOTSTRAP_URL:-${REVIEWER_GITEA_BASE_URL}}"
REVIEWER_GITEA_TEA_URL="${REVIEWER_GITEA_TEA_URL:-}"
REVIEWER_GITEA_PASSWORD="${REVIEWER_GITEA_PASSWORD:-}"
REVIEWER_GITEA_TOKEN="${REVIEWER_GITEA_TOKEN:-}"
REVIEWER_GITEA_TEA_LOGIN_NAME="${REVIEWER_GITEA_TEA_LOGIN_NAME:-reviewer}"
REVIEWER_GITEA_TEA_TOKEN_NAME="${REVIEWER_GITEA_TEA_TOKEN_NAME:-openclaw-reviewer}"
GIT_CREDENTIALS_FILE="${XDG_CONFIG_HOME_DIR}/git/credentials"

export HOME="${HOME_DIR}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME_DIR}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME_DIR}"
export XDG_STATE_HOME="${XDG_STATE_HOME_DIR}"
export GIT_CONFIG_GLOBAL="${GIT_CONFIG_GLOBAL_FILE}"

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
  local ready_url="${REVIEWER_GITEA_BOOTSTRAP_URL}/api/v1/users/${REVIEWER_GITEA_USERNAME}/tokens"
  local response_file=""
  local status=""
  local attempt=0

  response_file="$(mktemp /tmp/openclaw-reviewer-gitea-auth-ready.XXXXXX.json)"
  while (( attempt < 30 )); do
    status="$(
      curl -sS -o "$response_file" -w '%{http_code}' \
        --user "${REVIEWER_GITEA_USERNAME}:${REVIEWER_GITEA_PASSWORD}" \
        "${ready_url}"
    )"
    if [[ "$status" == "200" ]]; then
      rm -f "$response_file"
      return 0
    fi
    if [[ "$status" != "401" && "$status" != "404" && "$status" != "000" ]]; then
      echo "Gitea user auth for ${REVIEWER_GITEA_USERNAME} failed unexpectedly with HTTP ${status}" >&2
      cat "$response_file" >&2 || true
      rm -f "$response_file"
      exit 1
    fi
    attempt=$((attempt + 1))
    sleep 1
  done

  echo "Timed out waiting for Gitea user ${REVIEWER_GITEA_USERNAME} authentication to become ready." >&2
  cat "$response_file" >&2 || true
  rm -f "$response_file"
  exit 1
}

ensure_reviewer_gitea_token() {
  local tokens_url="${REVIEWER_GITEA_BOOTSTRAP_URL}/api/v1/users/${REVIEWER_GITEA_USERNAME}/tokens"
  local existing_token_ids=""
  local duplicate_token_ids=""
  local list_body_file=""
  local token_payload=""
  local token=""
  local create_body_file=""
  local create_status=""
  local create_attempt=0

  wait_for_gitea_user_auth
  list_body_file="$(mktemp /tmp/openclaw-reviewer-gitea-token-list.XXXXXX.json)"
  curl -fsS -u "${REVIEWER_GITEA_USERNAME}:${REVIEWER_GITEA_PASSWORD}" -o "$list_body_file" "${tokens_url}"
  existing_token_ids="$(extract_gitea_token_ids "${REVIEWER_GITEA_TEA_TOKEN_NAME}" <"$list_body_file" || true)"
  rm -f "$list_body_file"
  if [[ -n "${existing_token_ids}" ]]; then
    while IFS= read -r token_id; do
      [[ -n "${token_id}" ]] || continue
      curl -fsS -X DELETE -u "${REVIEWER_GITEA_USERNAME}:${REVIEWER_GITEA_PASSWORD}" "${tokens_url}/${token_id}" >/dev/null
    done <<<"${existing_token_ids}"
  fi

  token_payload="$(build_token_payload "${REVIEWER_GITEA_TEA_TOKEN_NAME}")"
  create_body_file="$(mktemp /tmp/openclaw-reviewer-gitea-token-create.XXXXXX.json)"
  while (( create_attempt < 5 )); do
    token=""
    create_status="$(
      curl -sS -o "$create_body_file" -w '%{http_code}' \
        -u "${REVIEWER_GITEA_USERNAME}:${REVIEWER_GITEA_PASSWORD}" \
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
      list_body_file="$(mktemp /tmp/openclaw-reviewer-gitea-token-list.XXXXXX.json)"
      curl -fsS -u "${REVIEWER_GITEA_USERNAME}:${REVIEWER_GITEA_PASSWORD}" -o "$list_body_file" "${tokens_url}"
      duplicate_token_ids="$(extract_gitea_token_ids "${REVIEWER_GITEA_TEA_TOKEN_NAME}" <"$list_body_file" || true)"
      rm -f "$list_body_file"
      if [[ -n "${duplicate_token_ids}" ]]; then
        while IFS= read -r token_id; do
          [[ -n "${token_id}" ]] || continue
          curl -fsS -X DELETE -u "${REVIEWER_GITEA_USERNAME}:${REVIEWER_GITEA_PASSWORD}" "${tokens_url}/${token_id}" >/dev/null
        done <<<"${duplicate_token_ids}"
      fi
      create_attempt=$((create_attempt + 1))
      sleep 1
      continue
    fi
    if [[ "$create_status" == "400" ]] && grep -q 'access token name has been used already' "$create_body_file"; then
      list_body_file="$(mktemp /tmp/openclaw-reviewer-gitea-token-list.XXXXXX.json)"
      curl -fsS -u "${REVIEWER_GITEA_USERNAME}:${REVIEWER_GITEA_PASSWORD}" -o "$list_body_file" "${tokens_url}"
      duplicate_token_ids="$(extract_gitea_token_ids "${REVIEWER_GITEA_TEA_TOKEN_NAME}" <"$list_body_file" || true)"
      rm -f "$list_body_file"
      if [[ -n "${duplicate_token_ids}" ]]; then
        while IFS= read -r token_id; do
          [[ -n "${token_id}" ]] || continue
          curl -fsS -X DELETE -u "${REVIEWER_GITEA_USERNAME}:${REVIEWER_GITEA_PASSWORD}" "${tokens_url}/${token_id}" >/dev/null
        done <<<"${duplicate_token_ids}"
      fi
      create_attempt=$((create_attempt + 1))
      sleep 1
      continue
    fi
    break
  done

  if [[ "$create_status" != "201" && "$create_status" != "200" ]]; then
    echo "Failed to create Gitea token ${REVIEWER_GITEA_TEA_TOKEN_NAME} for ${REVIEWER_GITEA_USERNAME} (HTTP ${create_status})." >&2
    cat "$create_body_file" >&2 || true
    rm -f "$create_body_file"
    exit 1
  fi

  echo "Created Gitea token payload for ${REVIEWER_GITEA_USERNAME} did not include a sha1 value." >&2
  cat "$create_body_file" >&2 || true
  rm -f "$create_body_file"
  exit 1
}

tea_ssh_host() {
  if [ -n "${REVIEWER_GITEA_HOST}" ]; then
    printf '%s\n' "${REVIEWER_GITEA_HOST}"
    return
  fi

  local host="${REVIEWER_GITEA_TEA_URL:-${REVIEWER_GITEA_BASE_URL}}"
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
- name: ${REVIEWER_GITEA_TEA_LOGIN_NAME}
  url: ${REVIEWER_GITEA_TEA_URL}
  token: ${REVIEWER_GITEA_TOKEN}
  default: true
  ssh_host: ${ssh_host}
  ssh_key: ""
  insecure: false
  user: ${REVIEWER_GITEA_USERNAME}
  created: ${created_at}
preferences:
  editor: false
  flag_defaults:
    remote: ""
EOF
  chmod 0600 "${XDG_CONFIG_HOME}/tea/config.yml"

  if [[ "${HOME}/.tea/config.yml" != "${XDG_CONFIG_HOME}/tea/config.yml" ]]; then
    if [[ -d "${HOME}/.tea" || -L "${HOME}/.tea" ]] || mkdir -p "${HOME}/.tea" 2>/dev/null; then
      cp "${XDG_CONFIG_HOME}/tea/config.yml" "${HOME}/.tea/config.yml"
      chmod 0600 "${HOME}/.tea/config.yml"
    fi
  fi
}

mkdir -p \
  "${XDG_CONFIG_HOME}/tea" \
  "$(dirname "${GIT_CONFIG_GLOBAL}")" \
  "${XDG_CACHE_HOME}" \
  "${XDG_STATE_HOME}"

touch "${GIT_CREDENTIALS_FILE}"

git config --global user.name "${REVIEWER_GITEA_USERNAME}"
git config --global user.email "${REVIEWER_GITEA_EMAIL}"
git config --global credential.helper "store --file ${GIT_CREDENTIALS_FILE}"
if [ -n "${REVIEWER_GITEA_BASE_URL}" ] && [ -n "${REVIEWER_GITEA_HOST}" ]; then
  git config --global url."${REVIEWER_GITEA_BASE_URL%/}/".insteadOf "ssh://git@${REVIEWER_GITEA_HOST}/"
  git config --global url."${REVIEWER_GITEA_BASE_URL%/}/".insteadOf "git@${REVIEWER_GITEA_HOST}:"
fi

if [ -n "${REVIEWER_GITEA_HOST}" ] && [ -n "${REVIEWER_GITEA_PASSWORD}" ]; then
  if [ -z "${REVIEWER_GITEA_BASE_URL}" ]; then
    case "${REVIEWER_GITEA_HOST}" in
      *.localtest.me) REVIEWER_GITEA_BASE_URL="http://${REVIEWER_GITEA_HOST}" ;;
      *) REVIEWER_GITEA_BASE_URL="https://${REVIEWER_GITEA_HOST}" ;;
    esac
  fi
  printf '%s\n' "${REVIEWER_GITEA_BASE_URL%/}" \
    | awk -v user="${REVIEWER_GITEA_USERNAME}" -v password="${REVIEWER_GITEA_PASSWORD}" '
        NF {
          sub(/^[^:]+:\/\//, "&" user ":" password "@")
          print
        }
      ' > "${GIT_CREDENTIALS_FILE}"
  chmod 0600 "${GIT_CREDENTIALS_FILE}"
fi

if [ -z "${REVIEWER_GITEA_BASE_URL}" ] && [ -n "${REVIEWER_GITEA_HOST}" ]; then
  case "${REVIEWER_GITEA_HOST}" in
    *.localtest.me) REVIEWER_GITEA_BASE_URL="http://${REVIEWER_GITEA_HOST}" ;;
    *) REVIEWER_GITEA_BASE_URL="https://${REVIEWER_GITEA_HOST}" ;;
  esac
fi

if [ -n "${REVIEWER_GITEA_BASE_URL}" ] && [ -n "${REVIEWER_GITEA_HOST}" ]; then
  git config --global url."${REVIEWER_GITEA_BASE_URL%/}/".insteadOf "ssh://git@${REVIEWER_GITEA_HOST}/"
  git config --global url."${REVIEWER_GITEA_BASE_URL%/}/".insteadOf "git@${REVIEWER_GITEA_HOST}:"
fi

if [ -z "${REVIEWER_GITEA_TEA_URL}" ]; then
  REVIEWER_GITEA_TEA_URL="${REVIEWER_GITEA_BASE_URL}"
fi

if [ -z "${REVIEWER_GITEA_TOKEN}" ] && [ -n "${REVIEWER_GITEA_BOOTSTRAP_URL}" ] && [ -n "${REVIEWER_GITEA_USERNAME}" ] && [ -n "${REVIEWER_GITEA_PASSWORD}" ]; then
  REVIEWER_GITEA_TOKEN="$(ensure_reviewer_gitea_token)"
fi

if [ -n "${REVIEWER_GITEA_TEA_URL}" ] && [ -n "${REVIEWER_GITEA_TOKEN}" ] && [ "${REVIEWER_GITEA_TOKEN}" != "null" ]; then
  write_tea_config
fi
