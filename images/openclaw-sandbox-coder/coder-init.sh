#!/usr/bin/env bash
set -eu

HOME_DIR="${HOME:-/workspace/.home}"
CODEX_HOME_DIR="${CODEX_HOME:-${HOME_DIR}/.codex}"
XDG_CONFIG_HOME_DIR="${XDG_CONFIG_HOME:-${HOME_DIR}/.config}"
XDG_CACHE_HOME_DIR="${XDG_CACHE_HOME:-${HOME_DIR}/.cache}"
XDG_STATE_HOME_DIR="${XDG_STATE_HOME:-${HOME_DIR}/.local/state}"
DOCKER_CONFIG_DIR="${DOCKER_CONFIG:-${HOME_DIR}/.docker}"

CODER_GITEA_USERNAME="${CODER_GITEA_USERNAME:-coder}"
CODER_GITEA_EMAIL="${CODER_GITEA_EMAIL:-coder@example.invalid}"
CODER_GITEA_HOST="${CODER_GITEA_HOST:-}"
CODER_GITEA_BASE_URL="${CODER_GITEA_BASE_URL:-}"
CODER_GITEA_PASSWORD="${CODER_GITEA_PASSWORD:-}"
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

mkdir -p \
  "${CODEX_HOME}" \
  "${XDG_CONFIG_HOME}/tea" \
  "${XDG_CACHE_HOME}" \
  "${XDG_STATE_HOME}" \
  "${DOCKER_CONFIG}"

CODEX_MODEL="${CODEX_MODEL:-openai/gpt-5.3-codex}"

# Write Codex CLI config. Strip the provider prefix because Codex CLI expects a bare model name.
codex_model_bare="${CODEX_MODEL#*/}"
cat > "${CODEX_HOME_DIR}/config.toml" <<EOF
model = "${codex_model_bare}"
EOF

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

if [ -n "${CODER_GITEA_BASE_URL}" ] && [ -n "${CODER_GITEA_USERNAME}" ] && [ -n "${CODER_GITEA_PASSWORD}" ]; then
  tokens_url="${CODER_GITEA_BASE_URL}/api/v1/users/${CODER_GITEA_USERNAME}/tokens"
  auth="${CODER_GITEA_USERNAME}:${CODER_GITEA_PASSWORD}"

  existing_token_ids="$(
    curl -fsS -u "${auth}" "${tokens_url}" \
      | jq -r --arg name "${CODER_GITEA_TEA_TOKEN_NAME}" '.[] | select(.name == $name) | .id' \
      || true
  )"
  if [ -n "${existing_token_ids}" ]; then
    for token_id in ${existing_token_ids}; do
      curl -fsS -X DELETE -u "${auth}" "${tokens_url}/${token_id}" >/dev/null || true
    done
  fi

  token="$(
    curl -fsS -u "${auth}" \
      -H 'Content-Type: application/json' \
      -d "{\"name\":\"${CODER_GITEA_TEA_TOKEN_NAME}\",\"scopes\":[\"all\"]}" \
      "${tokens_url}" 2>/dev/null \
      | jq -r '.sha1 // empty' \
      || true
  )"
  if [ -n "${token}" ]; then
    tea login add --name "${CODER_GITEA_TEA_LOGIN_NAME}" --url "${CODER_GITEA_BASE_URL}" --token "${token}" >/dev/null 2>&1 || true
  fi
fi

if [ -n "${CODER_REGISTRY_HOST}" ] && [ -n "${CODER_REGISTRY_USERNAME}" ] && [ -n "${CODER_REGISTRY_PASSWORD}" ]; then
  printf '%s' "${CODER_REGISTRY_PASSWORD}" \
    | docker login "${CODER_REGISTRY_HOST}" --username "${CODER_REGISTRY_USERNAME}" --password-stdin >/dev/null 2>&1 \
    || true
fi
