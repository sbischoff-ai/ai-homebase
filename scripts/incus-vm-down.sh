#!/usr/bin/env bash
set -euo pipefail

VM_NAME="${VM_NAME:-openclaw-sandbox}"

usage() {
  cat <<USAGE
Usage: $0 [options]

Delete the dedicated Incus VM used for OpenClaw sandboxing.

Options:
  --vm-name <name>       Incus instance name (default: ${VM_NAME})
  -h, --help             Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vm-name) VM_NAME="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if ! command -v incus >/dev/null 2>&1; then
  echo "Missing required dependency: incus" >&2
  exit 1
fi

if incus info "$VM_NAME" >/dev/null 2>&1; then
  echo "Deleting Incus VM ${VM_NAME}"
  incus delete --force "$VM_NAME"
  echo "Deleted Incus VM ${VM_NAME}"
else
  echo "Incus VM ${VM_NAME} does not exist; nothing to clean up"
fi
