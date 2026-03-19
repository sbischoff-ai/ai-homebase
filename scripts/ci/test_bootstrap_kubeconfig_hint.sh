#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../lib/logging.sh"

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  if [[ "$actual" != "$expected" ]]; then
    echo "Assertion failed: ${message}" >&2
    echo "Expected: ${expected}" >&2
    echo "Actual:   ${actual}" >&2
    exit 1
  fi
}

assert_eq \
  'export KUBECONFIG=/tmp/k3d-ai-homebase.yaml' \
  "$(print_kubeconfig_export_line '/tmp/k3d-ai-homebase.yaml')" \
  "prints a plain export command for simple paths"

assert_eq \
  'export KUBECONFIG=/tmp/k3d\ ai-homebase.yaml' \
  "$(print_kubeconfig_export_line '/tmp/k3d ai-homebase.yaml')" \
  "shell-escapes whitespace so the line stays copy-pasteable"

echo "Bootstrap kubeconfig hint output looks correct."
