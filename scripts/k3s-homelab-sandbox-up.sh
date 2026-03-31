#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/lib/logging.sh"

BOOTSTRAP_CONFIG_PATH="${BOOTSTRAP_CONFIG_PATH:-bootstrap.local.toml}"
VM_NAME="${VM_NAME:-openclaw-sandbox}"
HOST_ALIAS="${HOST_ALIAS:-openclaw-sandbox.homebase.internal}"
SHARED_OPENCLAW_STATE_SOURCE="${SHARED_OPENCLAW_STATE_SOURCE:-/var/lib/ai-homebase/openclaw-state}"
SHARED_OPENCLAW_STATE_TARGET="${SHARED_OPENCLAW_STATE_TARGET:-/home/node/.openclaw}"
INCUS_CONNECTION_INFO_PATH="${INCUS_CONNECTION_INFO_PATH:-}"
EXTRA_RESOLVE_HOSTS=()

usage() {
  cat <<USAGE
Usage: $0 [options]

Create or reuse the Incus-backed remote Docker sandbox VM for the homelab k3s path.

Options:
  --bootstrap-config <path>    Bootstrap config file used to discover the Nextcloud/Qdrant MCP hostnames (default: ${BOOTSTRAP_CONFIG_PATH})
  --vm-name <name>             Incus VM name (default: ${VM_NAME})
  --host-alias <name>          Hostname the VM should expose for the SSH-backed Docker endpoint (default: ${HOST_ALIAS})
  --shared-openclaw-state-source <path>
                                Host path shared with the sandbox VM for OpenClaw state (default: ${SHARED_OPENCLAW_STATE_SOURCE})
  --incus-connection-info <p>  Optional explicit Incus connection info env file
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
    --shared-openclaw-state-source) SHARED_OPENCLAW_STATE_SOURCE="$2"; shift 2 ;;
    --incus-connection-info) INCUS_CONNECTION_INFO_PATH="$2"; shift 2 ;;
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

NEXTCLOUD_MCP_HOST=""
QDRANT_MCP_HOST=""
GITEA_HOST=""
REGISTRY_HOST=""
OPENCLAW_HOST=""
MEMGRAPH_HOST=""
MEMGRAPH_LAB_HOST=""
if [[ -f "$BOOTSTRAP_CONFIG_PATH" ]]; then
  BOOTSTRAP_SHELL_VARS="$(python3 ./scripts/bootstrap-config.py shell-vars --config "$BOOTSTRAP_CONFIG_PATH")" || exit 1
  eval "$BOOTSTRAP_SHELL_VARS"
  NEXTCLOUD_MCP_HOST="${NEXTCLOUD_MCP_HOST:-}"
  QDRANT_MCP_HOST="${QDRANT_MCP_HOST:-}"
  GITEA_HOST="${GITEA_HOST:-}"
  REGISTRY_HOST="${REGISTRY_HOST:-}"
  OPENCLAW_HOST="${OPENCLAW_HOST:-}"
  MEMGRAPH_HOST="${MEMGRAPH_HOST:-}"
  MEMGRAPH_LAB_HOST="${MEMGRAPH_LAB_HOST:-}"
fi

INCUS_VM_CMD=(
  ./scripts/incus-vm-up.sh
  --vm-name "$VM_NAME"
  --host-alias "$HOST_ALIAS"
  --shared-openclaw-state-source "$SHARED_OPENCLAW_STATE_SOURCE"
  --shared-openclaw-state-target "$SHARED_OPENCLAW_STATE_TARGET"
)

if [[ -n "$NEXTCLOUD_MCP_HOST" ]]; then
  INCUS_VM_CMD+=(--resolve-host "$NEXTCLOUD_MCP_HOST")
fi
if [[ -n "$QDRANT_MCP_HOST" ]]; then
  INCUS_VM_CMD+=(--resolve-host "$QDRANT_MCP_HOST")
fi
if [[ -n "$GITEA_HOST" ]]; then
  INCUS_VM_CMD+=(--resolve-host "$GITEA_HOST")
fi
if [[ -n "$REGISTRY_HOST" ]]; then
  INCUS_VM_CMD+=(--resolve-host "$REGISTRY_HOST")
fi
if [[ -n "$OPENCLAW_HOST" ]]; then
  INCUS_VM_CMD+=(--resolve-host "$OPENCLAW_HOST")
fi
if [[ -n "$MEMGRAPH_HOST" ]]; then
  INCUS_VM_CMD+=(--resolve-host "$MEMGRAPH_HOST")
fi
if [[ -n "$MEMGRAPH_LAB_HOST" ]]; then
  INCUS_VM_CMD+=(--resolve-host "$MEMGRAPH_LAB_HOST")
fi

for resolve_host in "${EXTRA_RESOLVE_HOSTS[@]}"; do
  INCUS_VM_CMD+=(--resolve-host "$resolve_host")
done

run_quiet "${INCUS_VM_CMD[@]}"

echo "Homelab sandbox VM is ready."
echo "Summary:"
echo "  VM: ${VM_NAME}"
echo "  Host alias: ${HOST_ALIAS}"
echo "  Shared OpenClaw state: ${SHARED_OPENCLAW_STATE_SOURCE} -> ${SHARED_OPENCLAW_STATE_TARGET}"
if [[ -n "$NEXTCLOUD_MCP_HOST" ]]; then
  echo "  Nextcloud MCP host override inside sandbox: ${NEXTCLOUD_MCP_HOST}"
fi
if [[ -n "$QDRANT_MCP_HOST" ]]; then
  echo "  Qdrant MCP host override inside sandbox: ${QDRANT_MCP_HOST}"
fi
if [[ -n "$GITEA_HOST" ]]; then
  echo "  Gitea host override inside sandbox: ${GITEA_HOST}"
fi
if [[ -n "$REGISTRY_HOST" ]]; then
  echo "  Registry host override inside sandbox: ${REGISTRY_HOST}"
fi
if [[ -n "$OPENCLAW_HOST" ]]; then
  echo "  OpenClaw host override inside sandbox: ${OPENCLAW_HOST}"
fi
if [[ -n "$MEMGRAPH_HOST" ]]; then
  echo "  Memgraph host override inside sandbox: ${MEMGRAPH_HOST}"
fi
if [[ -n "$MEMGRAPH_LAB_HOST" ]]; then
  echo "  Memgraph Lab host override inside sandbox: ${MEMGRAPH_LAB_HOST}"
fi
echo "  Incus connection info: ${INCUS_CONNECTION_INFO_PATH}"
