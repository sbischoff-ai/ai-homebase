#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE="${PROFILE:-}"
BOOTSTRAP_CONFIG_PATH="${BOOTSTRAP_CONFIG_PATH:-bootstrap.local.toml}"
RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${KUBECONFIG:-}}"
KUBE_CONTEXT="${KUBE_CONTEXT:-}"
VALUES_FILES=()
REMOTE_DOCKER_SECRET_NAME="${REMOTE_DOCKER_SECRET_NAME:-}"
REMOTE_DOCKER_HOST="${REMOTE_DOCKER_HOST:-}"
REMOTE_DOCKER_PORT="${REMOTE_DOCKER_PORT:-}"
REMOTE_DOCKER_KEY_PATH="${REMOTE_DOCKER_KEY_PATH:-}"
VERBOSE=0

usage() {
  cat <<USAGE
Usage: $0 --profile <k3d|k3s> [options]

Run the shared bootstrap flow for a prepared cluster: bootstrap secrets and install/upgrade.

Options:
  --profile <k3d|k3s>          Supported target profile
  --bootstrap-config <path>    Bootstrap config file (default: ${BOOTSTRAP_CONFIG_PATH})
  --release-name <name>        Helm release name (default: ${RELEASE_NAME})
  --namespace <name>           Kubernetes namespace (default: ${NAMESPACE})
  --kubeconfig <path>          Optional kubeconfig path
  --kube-context <context>     Optional kube context
  --values-file <path>         Extra values file path (repeatable)
  --remote-docker-secret <n>   Override SSH secret name for OpenClaw remote Docker bootstrap
  --remote-docker-host <host>  Override OpenClaw remote Docker SSH host
  --remote-docker-port <port>  Override OpenClaw remote Docker SSH port
  --remote-docker-key <path>   Override OpenClaw remote Docker SSH private key path
  --verbose                    Stream full command output
  -h, --help                   Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --bootstrap-config) BOOTSTRAP_CONFIG_PATH="$2"; shift 2 ;;
    --release-name) RELEASE_NAME="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --kube-context) KUBE_CONTEXT="$2"; shift 2 ;;
    --values-file) VALUES_FILES+=("$2"); shift 2 ;;
    --remote-docker-secret) REMOTE_DOCKER_SECRET_NAME="$2"; shift 2 ;;
    --remote-docker-host) REMOTE_DOCKER_HOST="$2"; shift 2 ;;
    --remote-docker-port) REMOTE_DOCKER_PORT="$2"; shift 2 ;;
    --remote-docker-key) REMOTE_DOCKER_KEY_PATH="$2"; shift 2 ;;
    --verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

case "$PROFILE" in
  k3d|k3s) ;;
  *) echo "Missing or unsupported --profile. Use k3d or k3s." >&2; usage; exit 1 ;;
esac

BOOTSTRAP_SECRETS_CMD=(
  ./scripts/bootstrap-secrets.sh
  --profile "$PROFILE"
  --bootstrap-config "$BOOTSTRAP_CONFIG_PATH"
  --release-name "$RELEASE_NAME"
  --namespace "$NAMESPACE"
)
INSTALL_CMD=(
  ./scripts/install.sh
  --profile "$PROFILE"
  --bootstrap-config "$BOOTSTRAP_CONFIG_PATH"
  --release-name "$RELEASE_NAME"
  --namespace "$NAMESPACE"
)

if [[ -n "$KUBECONFIG_PATH" ]]; then
  BOOTSTRAP_SECRETS_CMD+=(--kubeconfig "$KUBECONFIG_PATH")
  INSTALL_CMD+=(--kubeconfig "$KUBECONFIG_PATH")
fi

if [[ -n "$KUBE_CONTEXT" ]]; then
  INSTALL_CMD+=(--kube-context "$KUBE_CONTEXT")
fi

if [[ -n "$REMOTE_DOCKER_SECRET_NAME" ]]; then
  BOOTSTRAP_SECRETS_CMD+=(--remote-docker-secret "$REMOTE_DOCKER_SECRET_NAME")
fi
if [[ -n "$REMOTE_DOCKER_HOST" ]]; then
  BOOTSTRAP_SECRETS_CMD+=(--remote-docker-host "$REMOTE_DOCKER_HOST")
fi
if [[ -n "$REMOTE_DOCKER_PORT" ]]; then
  BOOTSTRAP_SECRETS_CMD+=(--remote-docker-port "$REMOTE_DOCKER_PORT")
fi
if [[ -n "$REMOTE_DOCKER_KEY_PATH" ]]; then
  BOOTSTRAP_SECRETS_CMD+=(--remote-docker-key "$REMOTE_DOCKER_KEY_PATH")
fi

for values_file in "${VALUES_FILES[@]}"; do
  INSTALL_CMD+=(--values-file "$values_file")
done

if [[ "$VERBOSE" -eq 1 ]]; then
  BOOTSTRAP_SECRETS_CMD+=(--verbose)
fi

"${BOOTSTRAP_SECRETS_CMD[@]}"
"${INSTALL_CMD[@]}"
