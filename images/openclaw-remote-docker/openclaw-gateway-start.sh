#!/usr/bin/env bash
set -euo pipefail

warn() {
  echo >&2 "WARNING: $*"
}

CODER_WORKSPACE_HOME="/home/node/.openclaw/workspace-coder/.home"
ARCHITECT_WORKSPACE_HOME="/home/node/.openclaw/workspace-architect/.home"
AUDITOR_WORKSPACE_HOME="/home/node/.openclaw/workspace-auditor/.home"

seed_reviewer_workspace_login() {
  local workspace_home="$1"
  local label="$2"

  if ! env \
    HOME="${workspace_home}" \
    XDG_CONFIG_HOME="${workspace_home}/.config" \
    XDG_CACHE_HOME="${workspace_home}/.cache" \
    XDG_STATE_HOME="${workspace_home}/.local/state" \
    GIT_CONFIG_GLOBAL="${workspace_home}/.config/git/config" \
    reviewer-gitea-init.sh; then
    warn "reviewer-gitea-init.sh failed during ${label} startup"
    warn "continuing without seeded reviewer Gitea login for ${label}"
  fi
}

if command -v reviewer-gitea-init.sh >/dev/null 2>&1; then
  if ! reviewer-gitea-init.sh; then
    warn "reviewer-gitea-init.sh failed during gateway startup"
    warn "continuing without seeded reviewer Gitea login"
  fi
  seed_reviewer_workspace_login "${ARCHITECT_WORKSPACE_HOME}" "architect workspace"
  seed_reviewer_workspace_login "${AUDITOR_WORKSPACE_HOME}" "auditor workspace"
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

cd /app

if [ "$#" -eq 0 ]; then
  set -- node openclaw.mjs gateway --allow-unconfigured
fi

exec "$@"
