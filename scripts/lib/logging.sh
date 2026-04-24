#!/usr/bin/env bash

bootstrap_init_logging() {
  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"

  BOOTSTRAP_VERBOSE="${BOOTSTRAP_VERBOSE:-0}"
  if [[ "${BOOTSTRAP_VERBOSE}" == "true" ]]; then
    BOOTSTRAP_VERBOSE=1
  fi

  BOOTSTRAP_LOG_FILE="${BOOTSTRAP_LOG_FILE:-/tmp/ai-homebase-bootstrap-${timestamp}.log}"
  mkdir -p "$(dirname "$BOOTSTRAP_LOG_FILE")"
  if [[ ! -e "$BOOTSTRAP_LOG_FILE" ]]; then
    : > "$BOOTSTRAP_LOG_FILE"
  else
    touch "$BOOTSTRAP_LOG_FILE"
  fi

  export BOOTSTRAP_LOG_FILE
  export BOOTSTRAP_VERBOSE
}

step() {
  echo "==> $*"
}

ok() {
  echo "✔ $*"
}

warn() {
  echo "⚠ $*" >&2
}

fail() {
  echo "✖ $*" >&2
}

run_verbose() {
  "$@" 2>&1 | tee -a "$BOOTSTRAP_LOG_FILE"
  local status=${PIPESTATUS[0]}
  return "$status"
}

run_quiet() {
  if [[ "${BOOTSTRAP_VERBOSE:-0}" == "1" ]]; then
    run_verbose "$@"
  else
    "$@" >>"$BOOTSTRAP_LOG_FILE" 2>&1
  fi
}
