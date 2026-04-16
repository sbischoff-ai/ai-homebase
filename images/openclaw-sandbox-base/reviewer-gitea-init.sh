#!/usr/bin/env bash
set -euo pipefail

REVIEWER_GITEA_USERNAME="${REVIEWER_GITEA_USERNAME:-reviewer}"
REVIEWER_GITEA_EMAIL="${REVIEWER_GITEA_EMAIL:-reviewer@example.invalid}"
REVIEWER_GITEA_HOST="${REVIEWER_GITEA_HOST:-}"
REVIEWER_GITEA_BASE_URL="${REVIEWER_GITEA_BASE_URL:-}"
REVIEWER_GITEA_PASSWORD="${REVIEWER_GITEA_PASSWORD:-}"
REVIEWER_GITEA_TEA_LOGIN_NAME="${REVIEWER_GITEA_TEA_LOGIN_NAME:-reviewer}"
REVIEWER_GITEA_TEA_TOKEN_NAME="${REVIEWER_GITEA_TEA_TOKEN_NAME:-openclaw-reviewer}"

mkdir -p "${HOME}/.config/tea"

git config --global user.name "${REVIEWER_GITEA_USERNAME}"
git config --global user.email "${REVIEWER_GITEA_EMAIL}"

if [ -n "${REVIEWER_GITEA_HOST}" ] && [ -n "${REVIEWER_GITEA_PASSWORD}" ]; then
  cat > "${HOME}/.netrc" <<EOF
machine ${REVIEWER_GITEA_HOST}
  login ${REVIEWER_GITEA_USERNAME}
  password ${REVIEWER_GITEA_PASSWORD}
EOF
  chmod 0600 "${HOME}/.netrc"
fi

if [ -z "${REVIEWER_GITEA_BASE_URL}" ] && [ -n "${REVIEWER_GITEA_HOST}" ]; then
  case "${REVIEWER_GITEA_HOST}" in
    *.localtest.me) REVIEWER_GITEA_BASE_URL="http://${REVIEWER_GITEA_HOST}" ;;
    *) REVIEWER_GITEA_BASE_URL="https://${REVIEWER_GITEA_HOST}" ;;
  esac
fi

if [ -n "${REVIEWER_GITEA_BASE_URL}" ] && [ -n "${REVIEWER_GITEA_USERNAME}" ] && [ -n "${REVIEWER_GITEA_PASSWORD}" ]; then
  tokens_url="${REVIEWER_GITEA_BASE_URL}/api/v1/users/${REVIEWER_GITEA_USERNAME}/tokens"
  auth="${REVIEWER_GITEA_USERNAME}:${REVIEWER_GITEA_PASSWORD}"
  token="$(
    curl -fsS -u "${auth}" "${tokens_url}" 2>/dev/null \
      | jq -r --arg name "${REVIEWER_GITEA_TEA_TOKEN_NAME}" '.[] | select(.name == $name) | .sha1' \
      | head -n1
  )"
  if [ -z "${token}" ] || [ "${token}" = "null" ]; then
    token="$(
      curl -fsS -u "${auth}" \
        -H 'Content-Type: application/json' \
        -d "{\"name\":\"${REVIEWER_GITEA_TEA_TOKEN_NAME}\",\"scopes\":[\"all\"]}" \
        "${tokens_url}" \
        | jq -r '.sha1'
    )"
  fi
  if [ -n "${token}" ] && [ "${token}" != "null" ]; then
    tea login add --name "${REVIEWER_GITEA_TEA_LOGIN_NAME}" --url "${REVIEWER_GITEA_BASE_URL}" --token "${token}" >/dev/null 2>&1 || true
  fi
fi
