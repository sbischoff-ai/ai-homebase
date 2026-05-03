#!/usr/bin/env bash
set -euo pipefail

warn() {
  echo >&2 "WARNING: $*"
}

MCP_BRIDGE_PATH="/opt/openclaw-runtime/mcp/mcp-http-bridge.mjs"
CODER_WORKSPACE_HOME="/home/node/.openclaw/workspace-coder/.home"
ARCHITECT_WORKSPACE_HOME="/home/node/.openclaw/workspace-architect/.home"
AUDITOR_WORKSPACE_HOME="/home/node/.openclaw/workspace-auditor/.home"
OPENCLAW_WRITABLE_STATE="${OPENCLAW_STATE_DIR:-/home/node/.openclaw}"

mkdir -p \
  "${OPENCLAW_WRITABLE_STATE}/.config/tea" \
  "${OPENCLAW_WRITABLE_STATE}/.config/git" \
  "${OPENCLAW_WRITABLE_STATE}/.cache" \
  "${OPENCLAW_WRITABLE_STATE}/.local/state" \
  "${OPENCLAW_WRITABLE_STATE}/.summarize"

url_host() {
  local url="$1"
  url="${url#*://}"
  url="${url%%/*}"
  url="${url%%:*}"
  printf "%s\n" "${url}"
}

seed_gateway_reviewer_login() {
  local gateway_url="${REVIEWER_GITEA_BOOTSTRAP_URL:-${REVIEWER_GITEA_BASE_URL:-}}"
  local gateway_host="${REVIEWER_GITEA_BOOTSTRAP_HOST:-}"

  if [ -z "${gateway_url}" ]; then
    warn "reviewer Gitea gateway URL is not configured"
    warn "continuing without seeded reviewer Gitea login"
    return 0
  fi
  if [ -z "${gateway_host}" ]; then
    gateway_host="$(url_host "${gateway_url}")"
  fi

  if ! env \
    REVIEWER_GITEA_BASE_URL="${gateway_url}" \
    REVIEWER_GITEA_TEA_URL="${gateway_url}" \
    REVIEWER_GITEA_HOST="${gateway_host}" \
    reviewer-gitea-init.sh; then
    warn "reviewer-gitea-init.sh failed during gateway startup for ${gateway_url}"
    warn "continuing without seeded reviewer Gitea login"
  fi
}

seed_reviewer_workspace_login() {
  local workspace_home="$1"
  local label="$2"
  local reviewer_url="$3"
  local reviewer_host="$4"

  if [ -z "${reviewer_url}" ]; then
    warn "reviewer Gitea URL is not configured for ${label}"
    warn "continuing without seeded reviewer Gitea login for ${label}"
    return 0
  fi
  if [ -z "${reviewer_host}" ]; then
    reviewer_host="$(url_host "${reviewer_url}")"
  fi

  if ! env \
    HOME="${workspace_home}" \
    XDG_CONFIG_HOME="${workspace_home}/.config" \
    XDG_CACHE_HOME="${workspace_home}/.cache" \
    XDG_STATE_HOME="${workspace_home}/.local/state" \
    GIT_CONFIG_GLOBAL="${workspace_home}/.config/git/config" \
    REVIEWER_GITEA_BASE_URL="${reviewer_url}" \
    REVIEWER_GITEA_TEA_URL="${reviewer_url}" \
    REVIEWER_GITEA_HOST="${reviewer_host}" \
    reviewer-gitea-init.sh; then
    warn "reviewer-gitea-init.sh failed during ${label} startup"
    warn "continuing without seeded reviewer Gitea login for ${label}"
  fi
}

prewarm_mcp_server() {
  local name="$1"
  local required_tool="$2"
  shift 2

  if [ ! -s "${MCP_BRIDGE_PATH}" ]; then
    warn "MCP bridge ${MCP_BRIDGE_PATH} is missing; cannot prewarm ${name}"
    return 0
  fi

  local bridge_args=()
  while [ "$#" -gt 0 ]; do
    if [ "$1" = "--url" ] && [ -z "${2:-}" ]; then
      shift 2
      continue
    fi
    bridge_args+=("$1")
    shift
  done
  if [ "${#bridge_args[@]}" -eq 0 ]; then
    warn "MCP server ${name} has no configured URL; skipping prewarm"
    return 0
  fi

  local payload output attempt max_attempts
  payload="$(mktemp)"
  output="$(mktemp)"
  trap 'rm -f "${payload}" "${output}"' RETURN
  cat >"${payload}" <<'EOF'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"openclaw-startup-prewarm","version":"1.0.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
EOF

  max_attempts="${OPENCLAW_MCP_PREWARM_ATTEMPTS:-6}"
  attempt=1
  while [ "${attempt}" -le "${max_attempts}" ]; do
    if timeout "${OPENCLAW_MCP_PREWARM_TIMEOUT_SECONDS:-45}" node "${MCP_BRIDGE_PATH}" "${bridge_args[@]}" <"${payload}" >"${output}" 2>&1 \
      && grep -F "${required_tool}" "${output}" >/dev/null; then
      echo "MCP server ${name} prewarm succeeded."
      return 0
    fi
    warn "MCP server ${name} prewarm attempt ${attempt}/${max_attempts} did not return ${required_tool}"
    attempt=$((attempt + 1))
    sleep "${OPENCLAW_MCP_PREWARM_SLEEP_SECONDS:-10}"
  done

  warn "MCP server ${name} did not prewarm successfully; OpenClaw will still start"
}

if command -v reviewer-gitea-init.sh >/dev/null 2>&1; then
  gateway_reviewer_url="${REVIEWER_GITEA_BOOTSTRAP_URL:-${REVIEWER_GITEA_BASE_URL:-}}"
  gateway_reviewer_host="${REVIEWER_GITEA_BOOTSTRAP_HOST:-${REVIEWER_GITEA_HOST:-}}"
  architect_reviewer_url="${REVIEWER_GITEA_EXTERNAL_BASE_URL:-${CODER_GITEA_BASE_URL:-}}"
  architect_reviewer_host="${REVIEWER_GITEA_EXTERNAL_HOST:-${CODER_GITEA_HOST:-}}"

  seed_gateway_reviewer_login
  seed_reviewer_workspace_login "${ARCHITECT_WORKSPACE_HOME}" "architect workspace" "${architect_reviewer_url}" "${architect_reviewer_host}"
  seed_reviewer_workspace_login "${AUDITOR_WORKSPACE_HOME}" "auditor workspace" "${gateway_reviewer_url}" "${gateway_reviewer_host}"
else
  warn "reviewer-gitea-init.sh is not installed in the gateway image"
fi

if command -v coder-workspace-init.sh >/dev/null 2>&1; then
  if ! env \
    HOME="${CODER_WORKSPACE_HOME}" \
    CODEX_HOME="${CODER_WORKSPACE_HOME}/.codex" \
    XDG_CONFIG_HOME="${CODER_WORKSPACE_HOME}/.config" \
    XDG_CACHE_HOME="${CODER_WORKSPACE_HOME}/.cache" \
    XDG_STATE_HOME="${CODER_WORKSPACE_HOME}/.local/state" \
    DOCKER_CONFIG="${CODER_WORKSPACE_HOME}/.docker" \
    GIT_CONFIG_GLOBAL="${CODER_WORKSPACE_HOME}/.gitconfig" \
    coder-workspace-init.sh; then
    warn "coder-workspace-init.sh failed during gateway startup"
    warn "continuing without seeded coder workspace auth state"
  fi
else
  warn "coder-workspace-init.sh is not installed in the gateway image"
fi

prewarm_mcp_server \
  "nextcloud" \
  "nc_webdav_list_directory" \
  --url "${OPENCLAW_NEXTCLOUD_MCP_INTERNAL_URL:-}" \
  --url "${OPENCLAW_NEXTCLOUD_MCP_EXTERNAL_URL:-}" \
  --header "Authorization=${OPENCLAW_NEXTCLOUD_MCP_AUTH_HEADER:-}"

prewarm_mcp_server \
  "qdrant" \
  "qdrant-find" \
  --url "${OPENCLAW_QDRANT_MCP_INTERNAL_URL:-}" \
  --url "${OPENCLAW_QDRANT_MCP_EXTERNAL_URL:-}"

cd /app

if [ "$#" -eq 0 ]; then
  set -- node openclaw.mjs gateway --allow-unconfigured
fi

exec "$@"
