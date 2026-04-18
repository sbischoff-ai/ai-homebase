#!/usr/bin/env bash
set -euo pipefail

warn() {
  echo >&2 "WARNING: $*"
}

if command -v reviewer-gitea-init.sh >/dev/null 2>&1; then
  if ! reviewer-gitea-init.sh; then
    warn "reviewer-gitea-init.sh failed during gateway startup"
    warn "continuing without seeded reviewer Gitea login"
  fi
else
  warn "reviewer-gitea-init.sh is not installed in the gateway image"
fi

cd /app

if [ "$#" -eq 0 ]; then
  set -- node openclaw.mjs gateway --allow-unconfigured
fi

exec "$@"
