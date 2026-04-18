#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/lib/logging.sh"
source "$(dirname "$0")/lib/bootstrap-hosts.sh"

BOOTSTRAP_CONFIG_PATH="${BOOTSTRAP_CONFIG_PATH:-bootstrap.local.toml}"
VM_NAME="${VM_NAME:-gitea-actions-runner}"
HOST_ALIAS="${HOST_ALIAS:-gitea-actions-runner.homebase.internal}"
SSH_HOST_PORT="${SSH_HOST_PORT:-2223}"
INCUS_CONNECTION_INFO_PATH="${INCUS_CONNECTION_INFO_PATH:-}"
SSH_KEY_PATH="${SSH_KEY_PATH:-}"
EXTRA_RESOLVE_HOSTS=()

usage() {
  cat <<USAGE
Usage: $0 [options]

Create or reuse the Incus-backed Gitea Actions runner VM for the homelab k3s path.

Options:
  --bootstrap-config <path>    Bootstrap config file used to discover service hostnames (default: ${BOOTSTRAP_CONFIG_PATH})
  --vm-name <name>             Incus VM name (default: ${VM_NAME})
  --host-alias <name>          Hostname the VM should expose for the SSH-backed runner Docker endpoint (default: ${HOST_ALIAS})
  --ssh-host-port <port>       Host TCP port proxied to guest SSH 22 (default: ${SSH_HOST_PORT})
  --incus-connection-info <p>  Optional explicit Incus connection info env file
  --ssh-key-path <path>        Optional explicit SSH private key path for the runner VM
  --resolve-host <name>        Additional hostname to resolve inside the VM and its Docker containers (repeatable)
  --verbose                    Stream full command output
  -h, --help                   Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap-config) BOOTSTRAP_CONFIG_PATH="$2"; shift 2 ;;
    --vm-name) VM_NAME="$2"; shift 2 ;;
    --host-alias) HOST_ALIAS="$2"; shift 2 ;;
    --ssh-host-port) SSH_HOST_PORT="$2"; shift 2 ;;
    --incus-connection-info) INCUS_CONNECTION_INFO_PATH="$2"; shift 2 ;;
    --ssh-key-path) SSH_KEY_PATH="$2"; shift 2 ;;
    --resolve-host) EXTRA_RESOLVE_HOSTS+=("$2"); shift 2 ;;
    --verbose) BOOTSTRAP_VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$INCUS_CONNECTION_INFO_PATH" ]]; then
  INCUS_CONNECTION_INFO_PATH="${HOME}/.local/state/ai-homebase/incus/${VM_NAME}.env"
fi

bootstrap_init_logging

if [[ -f "$BOOTSTRAP_CONFIG_PATH" ]]; then
  BOOTSTRAP_SHELL_VARS="$(python3 ./scripts/bootstrap-config.py shell-vars --config "$BOOTSTRAP_CONFIG_PATH")" || exit 1
  eval "$BOOTSTRAP_SHELL_VARS"
  VM_NAME="${GITEA_ACTIONS_RUNNER_VM_NAME:-$VM_NAME}"
  HOST_ALIAS="${GITEA_ACTIONS_RUNNER_HOST_ALIAS:-$HOST_ALIAS}"
  SSH_HOST_PORT="${GITEA_ACTIONS_RUNNER_SSH_PORT:-$SSH_HOST_PORT}"
fi
if [[ -z "$SSH_KEY_PATH" ]]; then
  SSH_KEY_PATH="${HOME}/.local/state/ai-homebase/incus/${VM_NAME}-id_ed25519"
fi

INCUS_VM_CMD=(
  ./scripts/incus-vm-up.sh
  --vm-name "$VM_NAME"
  --host-alias "$HOST_ALIAS"
  --ssh-host-port "$SSH_HOST_PORT"
  --ssh-key-path "$SSH_KEY_PATH"
  --remote-user-gecos "Gitea Actions runner Docker user"
)

append_bootstrap_resolve_hosts INCUS_VM_CMD

for resolve_host in "${EXTRA_RESOLVE_HOSTS[@]}"; do
  INCUS_VM_CMD+=(--resolve-host "$resolve_host")
done

run_quiet "${INCUS_VM_CMD[@]}"

echo "Homelab Gitea Actions runner VM is ready."
echo "Summary:"
echo "  VM: ${VM_NAME}"
echo "  Host alias: ${HOST_ALIAS}"
echo "  SSH proxy port: ${SSH_HOST_PORT}"
echo "  SSH key path: ${SSH_KEY_PATH}"
echo "  Incus connection info: ${INCUS_CONNECTION_INFO_PATH}"
