#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/lib/logging.sh"
source "$(dirname "$0")/lib/bootstrap-hosts.sh"

BOOTSTRAP_CONFIG_PATH="${BOOTSTRAP_CONFIG_PATH:-bootstrap.local.toml}"
SANDBOX_VM_NAME="${SANDBOX_VM_NAME:-openclaw-sandbox}"
RUNNER_VM_NAME="${RUNNER_VM_NAME:-gitea-actions-runner}"

usage() {
  cat <<USAGE
Usage: $0 [options]

Stop the ai-homebase k3s runtime without uninstalling packages, deleting Incus state, or removing durable host data.

Options:
  --bootstrap-config <path>  Bootstrap config file used to discover the Gitea Actions runner VM name (default: ${BOOTSTRAP_CONFIG_PATH})
  --sandbox-vm-name <name>   Incus sandbox VM name (default: ${SANDBOX_VM_NAME})
  --runner-vm-name <name>    Incus runner VM name override (default: ${RUNNER_VM_NAME})
  --verbose                  Stream full command output
  -h, --help                 Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap-config) BOOTSTRAP_CONFIG_PATH="$2"; shift 2 ;;
    --sandbox-vm-name) SANDBOX_VM_NAME="$2"; shift 2 ;;
    --runner-vm-name) RUNNER_VM_NAME="$2"; shift 2 ;;
    --verbose) BOOTSTRAP_VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

bootstrap_init_logging
trap 'fail "k3s runtime shutdown failed. Log: ${BOOTSTRAP_LOG_FILE}"' ERR

for cmd in incus python3 systemctl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Missing required dependency: $cmd"
    exit 1
  fi
done
if [[ "${EUID}" -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
  fail "Missing required dependency: sudo"
  exit 1
fi

if [[ -f "${BOOTSTRAP_CONFIG_PATH}" ]]; then
  bootstrap_load_shell_vars "${BOOTSTRAP_CONFIG_PATH}"
  RUNNER_VM_NAME="${GITEA_ACTIONS_RUNNER_VM_NAME:-${RUNNER_VM_NAME}}"
fi

as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

run_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    run_quiet "$@"
  else
    run_quiet sudo "$@"
  fi
}

stop_vm_if_present() {
  local vm_name="$1"
  local label="$2"

  if as_root incus info "${vm_name}" >/dev/null 2>&1; then
    step "Stopping ${label} ${vm_name}"
    run_root incus stop "${vm_name}" --force
    ok "${label} stopped"
  else
    ok "${label} ${vm_name} is already absent"
  fi
}

stop_vm_if_present "${SANDBOX_VM_NAME}" "sandbox VM"
stop_vm_if_present "${RUNNER_VM_NAME}" "Gitea Actions runner VM"

step "Stopping k3s"
run_root systemctl stop k3s
ok "k3s stopped"

echo
echo "k3s runtime has been stopped."
echo "Summary:"
echo "  Sandbox VM: ${SANDBOX_VM_NAME}"
echo "  Gitea Actions runner VM: ${RUNNER_VM_NAME}"
echo "  k3s service: stopped"
echo "  Durable host state, Incus definitions, and installed binaries were left in place."
echo "  Bootstrap log: ${BOOTSTRAP_LOG_FILE}"
