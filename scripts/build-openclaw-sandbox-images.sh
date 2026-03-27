#!/usr/bin/env bash
set -euo pipefail

BASE_IMAGE="${BASE_IMAGE:-openclaw-sandbox:bookworm-slim}"
BASE_DOCKERFILE="${BASE_DOCKERFILE:-images/openclaw-sandbox-base/Dockerfile}"
CODER_IMAGE="${CODER_IMAGE:-openclaw-sandbox-coder:bookworm-slim}"
CODER_DOCKERFILE="${CODER_DOCKERFILE:-images/openclaw-sandbox-coder/Dockerfile}"

usage() {
  cat <<USAGE
Usage: $0 [options]

Build repo-managed OpenClaw sandbox images needed by this stack.

Options:
  --base-image <image[:tag]>    Override the base sandbox image tag (default: ${BASE_IMAGE})
  --base-dockerfile <path>      Override the base sandbox Dockerfile path (default: ${BASE_DOCKERFILE})
  --coder-image <image[:tag]>   Override the coder sandbox image tag (default: ${CODER_IMAGE})
  --coder-dockerfile <path>     Override the coder sandbox Dockerfile path (default: ${CODER_DOCKERFILE})
  -h, --help                    Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-image) BASE_IMAGE="$2"; shift 2 ;;
    --base-dockerfile) BASE_DOCKERFILE="$2"; shift 2 ;;
    --coder-image) CODER_IMAGE="$2"; shift 2 ;;
    --coder-dockerfile) CODER_DOCKERFILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  echo "docker CLI is required to build sandbox images" >&2
  exit 1
fi

if ! docker image inspect "${BASE_IMAGE}" >/dev/null 2>&1; then
  echo "Building ${BASE_IMAGE} from ${BASE_DOCKERFILE}"
  docker build -f "${BASE_DOCKERFILE}" -t "${BASE_IMAGE}" .
else
  echo "Reusing existing ${BASE_IMAGE}"
fi

echo "Building ${CODER_IMAGE} from ${CODER_DOCKERFILE}"
docker build -f "${CODER_DOCKERFILE}" -t "${CODER_IMAGE}" .
