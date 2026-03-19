#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-ai-homebase-dev}"
VM_NAME="${VM_NAME:-openclaw-sandbox}"

usage() {
  cat <<USAGE
Usage: $0 [options]

Delete the local k3d cluster and the Incus VM used for OpenClaw sandboxing.

Options:
  --cluster-name <name>   k3d cluster name (default: ${CLUSTER_NAME})
  --vm-name <name>        Incus instance name (default: ${VM_NAME})
  -h, --help              Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster-name) CLUSTER_NAME="$2"; shift 2 ;;
    --vm-name) VM_NAME="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

"$(cd "$(dirname "$0")" && pwd)/k3d-down.sh" --cluster-name "$CLUSTER_NAME"
"$(cd "$(dirname "$0")" && pwd)/incus-vm-down.sh" --vm-name "$VM_NAME"
