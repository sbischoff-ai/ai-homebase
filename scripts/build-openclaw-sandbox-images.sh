#!/usr/bin/env bash
set -euo pipefail

GATEWAY_IMAGE="${GATEWAY_IMAGE:-openclaw-remote-docker:bookworm-slim}"
GATEWAY_DOCKERFILE="${GATEWAY_DOCKERFILE:-images/openclaw-remote-docker/Dockerfile}"
BASE_IMAGE="${BASE_IMAGE:-openclaw-sandbox:bookworm-slim}"
BASE_DOCKERFILE="${BASE_DOCKERFILE:-images/openclaw-sandbox-base/Dockerfile}"
ARCHIVIST_IMAGE="${ARCHIVIST_IMAGE:-openclaw-sandbox-archivist:bookworm-slim}"
ARCHIVIST_DOCKERFILE="${ARCHIVIST_DOCKERFILE:-images/openclaw-sandbox-archivist/Dockerfile}"
CODER_IMAGE="${CODER_IMAGE:-openclaw-sandbox-coder:bookworm-slim}"
CODER_DOCKERFILE="${CODER_DOCKERFILE:-images/openclaw-sandbox-coder/Dockerfile}"

usage() {
  cat <<USAGE
Usage: $0 [options]

Build repo-managed OpenClaw sandbox images needed by this stack.

Options:
  --gateway-image <image[:tag]> Override the gateway image tag (default: ${GATEWAY_IMAGE})
  --gateway-dockerfile <path>   Override the gateway Dockerfile path (default: ${GATEWAY_DOCKERFILE})
  --base-image <image[:tag]>    Override the base sandbox image tag (default: ${BASE_IMAGE})
  --base-dockerfile <path>      Override the base sandbox Dockerfile path (default: ${BASE_DOCKERFILE})
  --archivist-image <image[:tag]> Override the archivist sandbox image tag (default: ${ARCHIVIST_IMAGE})
  --archivist-dockerfile <path> Override the archivist sandbox Dockerfile path (default: ${ARCHIVIST_DOCKERFILE})
  --coder-image <image[:tag]>   Override the coder sandbox image tag (default: ${CODER_IMAGE})
  --coder-dockerfile <path>     Override the coder sandbox Dockerfile path (default: ${CODER_DOCKERFILE})
  -h, --help                    Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gateway-image) GATEWAY_IMAGE="$2"; shift 2 ;;
    --gateway-dockerfile) GATEWAY_DOCKERFILE="$2"; shift 2 ;;
    --base-image) BASE_IMAGE="$2"; shift 2 ;;
    --base-dockerfile) BASE_DOCKERFILE="$2"; shift 2 ;;
    --archivist-image) ARCHIVIST_IMAGE="$2"; shift 2 ;;
    --archivist-dockerfile) ARCHIVIST_DOCKERFILE="$2"; shift 2 ;;
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

echo "Building ${GATEWAY_IMAGE} from ${GATEWAY_DOCKERFILE}"
docker build -f "${GATEWAY_DOCKERFILE}" -t "${GATEWAY_IMAGE}" .

echo "Building ${BASE_IMAGE} from ${BASE_DOCKERFILE}"
docker build -f "${BASE_DOCKERFILE}" -t "${BASE_IMAGE}" .

echo "Building ${ARCHIVIST_IMAGE} from ${ARCHIVIST_DOCKERFILE}"
docker build -f "${ARCHIVIST_DOCKERFILE}" -t "${ARCHIVIST_IMAGE}" .

echo "Building ${CODER_IMAGE} from ${CODER_DOCKERFILE}"
docker build -f "${CODER_DOCKERFILE}" -t "${CODER_IMAGE}" .
