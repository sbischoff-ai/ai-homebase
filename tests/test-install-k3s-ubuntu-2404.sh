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

assert_not_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "${haystack}" == *"${needle}"* ]]; then
    printf 'expected content not to contain: %s\n' "${needle}" >&2
    exit 1
  fi
}

assert_contains "${script_contents}" "apt-transport-https"
assert_contains "${script_contents}" "qemu-system-modules-spice"
assert_contains "${script_contents}" "helm kubectl incus incus-agent virtiofsd"
assert_contains "${script_contents}" "/etc/systemd/system/incus.service.d/10-ai-homebase-agent-path.conf"
assert_contains "${script_contents}" "Environment=PATH=/usr/libexec/incus:"
assert_contains "${script_contents}" "systemctl daemon-reload"
assert_contains "${script_contents}" "usermod -aG incus-admin"
assert_contains "${script_contents}" "OPENCLAW_SHARED_STATE_DIR"
assert_contains "${script_contents}" 'install -d -m 0775 -o "${TARGET_UID}" -g "${TARGET_GID}" "${OPENCLAW_SHARED_STATE_DIR}"'
assert_contains "${script_contents}" './scripts/bootstrap-stack.sh --profile k3s --bootstrap-config bootstrap.local.toml --shared-openclaw-state-source ${OPENCLAW_SHARED_STATE_DIR}'
assert_not_contains "${script_contents}" "systemctl enable --now k3s"
assert_not_contains "${script_contents}" "systemctl enable --now incus"
assert_not_contains "${script_contents}" "ensure_ingress_nginx"
assert_not_contains "${script_contents}" "incus admin init --auto"

echo "install k3s ubuntu tests passed"
