#!/usr/bin/env bash
set -euo pipefail

GATEWAY_IMAGE="${GATEWAY_IMAGE:-openclaw-remote-docker:trixie-slim}"
GATEWAY_DOCKERFILE="${GATEWAY_DOCKERFILE:-images/openclaw-remote-docker/Dockerfile}"
BASE_IMAGE="${BASE_IMAGE:-openclaw-sandbox:trixie-slim}"
BASE_DOCKERFILE="${BASE_DOCKERFILE:-images/openclaw-sandbox-base/Dockerfile}"
CODER_IMAGE="${CODER_IMAGE:-openclaw-sandbox-coder:trixie-slim}"
CODER_DOCKERFILE="${CODER_DOCKERFILE:-images/openclaw-sandbox-coder/Dockerfile}"
GITEA_ACTIONS_JOB_IMAGE="${GITEA_ACTIONS_JOB_IMAGE:-gitea-actions-job:trixie-slim}"
GITEA_ACTIONS_JOB_DOCKERFILE="${GITEA_ACTIONS_JOB_DOCKERFILE:-images/gitea-actions-job/Dockerfile}"

usage() {
  cat <<USAGE
Usage: $0 [options]

Build repo-managed OpenClaw sandbox images needed by this stack.

Options:
  --gateway-image <image[:tag]> Override the gateway image tag (default: ${GATEWAY_IMAGE})
  --gateway-dockerfile <path>   Override the gateway Dockerfile path (default: ${GATEWAY_DOCKERFILE})
  --base-image <image[:tag]>    Override the base sandbox image tag (default: ${BASE_IMAGE})
  --base-dockerfile <path>      Override the base sandbox Dockerfile path (default: ${BASE_DOCKERFILE})
  --coder-image <image[:tag]>   Override the coder sandbox image tag (default: ${CODER_IMAGE})
  --coder-dockerfile <path>     Override the coder sandbox Dockerfile path (default: ${CODER_DOCKERFILE})
  --gitea-actions-job-image <image[:tag]>
                                Override the Gitea Actions job image tag (default: ${GITEA_ACTIONS_JOB_IMAGE})
  --gitea-actions-job-dockerfile <path>
                                Override the Gitea Actions job Dockerfile path (default: ${GITEA_ACTIONS_JOB_DOCKERFILE})
  -h, --help                    Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gateway-image) GATEWAY_IMAGE="$2"; shift 2 ;;
    --gateway-dockerfile) GATEWAY_DOCKERFILE="$2"; shift 2 ;;
    --base-image) BASE_IMAGE="$2"; shift 2 ;;
    --base-dockerfile) BASE_DOCKERFILE="$2"; shift 2 ;;
    --coder-image) CODER_IMAGE="$2"; shift 2 ;;
    --coder-dockerfile) CODER_DOCKERFILE="$2"; shift 2 ;;
    --gitea-actions-job-image) GITEA_ACTIONS_JOB_IMAGE="$2"; shift 2 ;;
    --gitea-actions-job-dockerfile) GITEA_ACTIONS_JOB_DOCKERFILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  echo "docker CLI is required to build sandbox images" >&2
  exit 1
fi

build_image() {
  local image="$1"
  local dockerfile="$2"
  local context_dir

  if [[ ! -f "$dockerfile" ]]; then
    echo "Dockerfile not found: ${dockerfile}" >&2
    exit 1
  fi

  context_dir="$(dirname "$dockerfile")"
  echo "Building ${image} from ${dockerfile} (context: ${context_dir})"
  docker build -f "$dockerfile" -t "$image" "$context_dir"
}

build_image "${GATEWAY_IMAGE}" "${GATEWAY_DOCKERFILE}"
build_image "${BASE_IMAGE}" "${BASE_DOCKERFILE}"
build_image "${CODER_IMAGE}" "${CODER_DOCKERFILE}"
build_image "${GITEA_ACTIONS_JOB_IMAGE}" "${GITEA_ACTIONS_JOB_DOCKERFILE}"
