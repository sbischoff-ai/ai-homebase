#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-ai-homebase-dev}"
VM_NAME="${VM_NAME:-openclaw-sandbox}"
BOOTSTRAP_CONFIG_PATH="${BOOTSTRAP_CONFIG_PATH:-}"
GITEA_ACTIONS_ENABLED="${GITEA_ACTIONS_ENABLED:-false}"
GITEA_ACTIONS_RUNNER_VM_NAME="${GITEA_ACTIONS_RUNNER_VM_NAME:-gitea-actions-runner}"
SHARED_OPENCLAW_STATE_SOURCE="${SHARED_OPENCLAW_STATE_SOURCE:-${HOME}/.local/state/ai-homebase/openclaw-state}"
KEEP_OPENCLAW_STATE=0

usage() {
  cat <<USAGE
Usage: $0 [options]

Delete the local k3d cluster, the Incus VM used for OpenClaw sandboxing,
the optional Gitea Actions runner VM when enabled, and the shared local
OpenClaw state directory by default.

Options:
  --cluster-name <name>              k3d cluster name (default: ${CLUSTER_NAME})
  --vm-name <name>                   Incus instance name (default: ${VM_NAME})
  --bootstrap-config <path>          Bootstrap config file used to detect optional companion VMs
  --runner-vm-name <name>            Incus runner VM name (default: ${GITEA_ACTIONS_RUNNER_VM_NAME})
  --shared-openclaw-state-source <p> Shared OpenClaw host-state path (default: ${SHARED_OPENCLAW_STATE_SOURCE})
  --keep-openclaw-state              Preserve the shared OpenClaw host-state directory
  -h, --help                         Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster-name) CLUSTER_NAME="$2"; shift 2 ;;
    --vm-name) VM_NAME="$2"; shift 2 ;;
    --bootstrap-config) BOOTSTRAP_CONFIG_PATH="$2"; shift 2 ;;
    --runner-vm-name) GITEA_ACTIONS_RUNNER_VM_NAME="$2"; shift 2 ;;
    --shared-openclaw-state-source) SHARED_OPENCLAW_STATE_SOURCE="$2"; shift 2 ;;
    --keep-openclaw-state) KEEP_OPENCLAW_STATE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$BOOTSTRAP_CONFIG_PATH" && -f bootstrap.local.toml ]]; then
  BOOTSTRAP_CONFIG_PATH="bootstrap.local.toml"
fi

if [[ -n "$BOOTSTRAP_CONFIG_PATH" ]]; then
  if [[ ! -f "$BOOTSTRAP_CONFIG_PATH" ]]; then
    echo "Bootstrap config not found: ${BOOTSTRAP_CONFIG_PATH}" >&2
    exit 1
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    echo "Missing required dependency: python3" >&2
    exit 1
  fi
  eval "$(python3 ./scripts/bootstrap-config.py shell-vars --config "$BOOTSTRAP_CONFIG_PATH")"
fi

echo "Removing local k3d cluster ${CLUSTER_NAME}"
"$(cd "$(dirname "$0")" && pwd)/k3d-down.sh" --cluster-name "$CLUSTER_NAME"
echo "Removing Incus VM ${VM_NAME}"
"$(cd "$(dirname "$0")" && pwd)/incus-vm-down.sh" --vm-name "$VM_NAME"
if [[ "${GITEA_ACTIONS_ENABLED}" == "true" && "$GITEA_ACTIONS_RUNNER_VM_NAME" != "$VM_NAME" ]]; then
  echo "Removing Incus Gitea Actions runner VM ${GITEA_ACTIONS_RUNNER_VM_NAME}"
  "$(cd "$(dirname "$0")" && pwd)/incus-vm-down.sh" --vm-name "$GITEA_ACTIONS_RUNNER_VM_NAME"
fi

if [[ "$KEEP_OPENCLAW_STATE" -eq 1 ]]; then
  echo "Preserving shared OpenClaw state at ${SHARED_OPENCLAW_STATE_SOURCE}"
elif [[ -d "$SHARED_OPENCLAW_STATE_SOURCE" ]]; then
  echo "Removing shared OpenClaw state at ${SHARED_OPENCLAW_STATE_SOURCE}"
  rm -rf "$SHARED_OPENCLAW_STATE_SOURCE"
  echo "Removed shared OpenClaw state at ${SHARED_OPENCLAW_STATE_SOURCE}"
else
  echo "Shared OpenClaw state path ${SHARED_OPENCLAW_STATE_SOURCE} does not exist; nothing to clean up"
fi
