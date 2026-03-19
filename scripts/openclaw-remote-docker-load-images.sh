#!/usr/bin/env bash
set -euo pipefail

DOCKER_HOST_VALUE="${DOCKER_HOST:-}"
IMAGES=()

usage() {
  cat <<USAGE
Usage: $0 --docker-host <ssh://user@host:port> --image <image[:tag]> [--image <image[:tag]> ...]

Ensure one or more OpenClaw sandbox images are available on a remote Docker daemon.
Each image must already exist locally; the script streams it to the remote daemon with
"docker save | docker load" only when the remote host does not already have it.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --docker-host) DOCKER_HOST_VALUE="$2"; shift 2 ;;
    --image) IMAGES+=("$2"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$DOCKER_HOST_VALUE" ]]; then
  echo "--docker-host (or DOCKER_HOST env var) is required" >&2
  exit 1
fi

if [[ ${#IMAGES[@]} -eq 0 ]]; then
  echo "At least one --image is required" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker CLI is required" >&2
  exit 1
fi

for image in "${IMAGES[@]}"; do
  echo "Checking local image: ${image}"
  docker image inspect "$image" >/dev/null

  if DOCKER_HOST="$DOCKER_HOST_VALUE" docker image inspect "$image" >/dev/null 2>&1; then
    echo "Remote already has ${image}"
    continue
  fi

  echo "Streaming ${image} to ${DOCKER_HOST_VALUE}"
  docker image save "$image" | DOCKER_HOST="$DOCKER_HOST_VALUE" docker load >/dev/null
  echo "Loaded ${image} onto ${DOCKER_HOST_VALUE}"
done
