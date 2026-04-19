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

tea_ssh_host() {
  if [ -n "${REVIEWER_GITEA_HOST}" ]; then
    printf '%s\n' "${REVIEWER_GITEA_HOST}"
    return
  fi

  local host="${REVIEWER_GITEA_BASE_URL#*://}"
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
  url: ${REVIEWER_GITEA_BASE_URL}
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

if [ -z "${REVIEWER_GITEA_TOKEN}" ] && [ -n "${REVIEWER_GITEA_BASE_URL}" ] && [ -n "${REVIEWER_GITEA_USERNAME}" ] && [ -n "${REVIEWER_GITEA_PASSWORD}" ]; then
  tokens_url="${REVIEWER_GITEA_BASE_URL}/api/v1/users/${REVIEWER_GITEA_USERNAME}/tokens"
  auth="${REVIEWER_GITEA_USERNAME}:${REVIEWER_GITEA_PASSWORD}"
  REVIEWER_GITEA_TOKEN="$(
    curl -fsS -u "${auth}" "${tokens_url}" 2>/dev/null \
      | jq -r --arg name "${REVIEWER_GITEA_TEA_TOKEN_NAME}" '.[] | select(.name == $name) | .sha1' \
      | head -n1
  )"
  if [ -z "${REVIEWER_GITEA_TOKEN}" ] || [ "${REVIEWER_GITEA_TOKEN}" = "null" ]; then
    REVIEWER_GITEA_TOKEN="$(
      curl -fsS -u "${auth}" \
        -H 'Content-Type: application/json' \
        -d "{\"name\":\"${REVIEWER_GITEA_TEA_TOKEN_NAME}\",\"scopes\":[\"all\"]}" \
        "${tokens_url}" \
        | jq -r '.sha1'
    )"
  fi
fi

if [ -n "${REVIEWER_GITEA_BASE_URL}" ] && [ -n "${REVIEWER_GITEA_TOKEN}" ] && [ "${REVIEWER_GITEA_TOKEN}" != "null" ]; then
  write_tea_config
fi
