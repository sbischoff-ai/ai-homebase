#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
script_path="${REPO_ROOT}/scripts/install-k3s-ubuntu-2404.sh"
script_contents="$(cat "${script_path}")"

assert_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "${haystack}" != *"${needle}"* ]]; then
    printf 'expected content to contain: %s\n' "${needle}" >&2
    exit 1
  fi
}

assert_contains "${script_contents}" "apt-transport-https"
assert_contains "${script_contents}" "helm kubectl incus"
assert_contains "${script_contents}" "systemctl enable --now k3s"
assert_contains "${script_contents}" "systemctl enable --now incus"
assert_contains "${script_contents}" "usermod -aG incus-admin"
assert_contains "${script_contents}" "OPENCLAW_SHARED_STATE_DIR"
assert_contains "${script_contents}" "install -d -m 0775 -o 1000 -g 1000"

echo "install k3s ubuntu tests passed"
