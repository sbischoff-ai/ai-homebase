#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-ai-homebase-dev}"

usage() {
  cat <<USAGE
Usage: $0 [options]

Delete the local k3d cluster used for ai-homebase development.

Options:
  --cluster-name <name>       k3d cluster name (default: ${CLUSTER_NAME})
  -h, --help                  Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster-name) CLUSTER_NAME="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if ! command -v k3d >/dev/null 2>&1; then
  echo "Missing required dependency: k3d" >&2
  exit 1
fi

if k3d kubeconfig get "$CLUSTER_NAME" >/dev/null 2>&1; then
  echo "Deleting k3d cluster ${CLUSTER_NAME}"
  k3d cluster delete "$CLUSTER_NAME"
  echo "Deleted k3d cluster ${CLUSTER_NAME}"
else
  echo "k3d cluster ${CLUSTER_NAME} does not exist; nothing to clean up"
fi
