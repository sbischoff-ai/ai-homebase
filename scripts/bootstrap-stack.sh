#!/usr/bin/env bash
set -Eeuo pipefail

PROFILE="${PROFILE:-}"
BOOTSTRAP_CONFIG_PATH="${BOOTSTRAP_CONFIG_PATH:-bootstrap.local.toml}"
RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-}"
RAW_KUBECONFIG="${KUBECONFIG:-}"
KUBE_CONTEXT="${KUBE_CONTEXT:-}"
VALUES_FILES=()
SET_ARGS=()
REMOTE_DOCKER_SECRET_NAME="${REMOTE_DOCKER_SECRET_NAME:-}"
REMOTE_DOCKER_HOST="${REMOTE_DOCKER_HOST:-}"
REMOTE_DOCKER_PORT="${REMOTE_DOCKER_PORT:-}"
REMOTE_DOCKER_KEY_PATH="${REMOTE_DOCKER_KEY_PATH:-}"
INCUS_VM_NAME="${INCUS_VM_NAME:-openclaw-sandbox}"
INCUS_CONNECTION_INFO_PATH="${INCUS_CONNECTION_INFO_PATH:-}"
SHARED_OPENCLAW_STATE_SOURCE="${SHARED_OPENCLAW_STATE_SOURCE:-}"
CLUSTER_NAME="${CLUSTER_NAME:-ai-homebase-dev}"
VERBOSE=0
default_k3d_kubeconfig_path() {
  printf '%s/.kube/k3d-%s.yaml' "$HOME" "$CLUSTER_NAME"
}

normalize_kubeconfig_path() {
  local candidate="${1:-}"
  case "$candidate" in
    '${KUBECONFIG:-'*'}')
      candidate="${candidate#'${KUBECONFIG:-'}"
      candidate="${candidate%\}}"
      ;;
    'KUBECONFIG:-'*)
      candidate="${candidate#KUBECONFIG:-}"
      ;;
  esac
  printf '%s' "$candidate"
}

usage() {
  cat <<USAGE
Usage: $0 --profile <k3d|k3s> [options]

Run the full ai-homebase bootstrap: target runtime setup, shared apply, GitOps handoff, and smoke checks.

Options:
  --profile <k3d|k3s>          Supported target profile
  --bootstrap-config <path>    Bootstrap config file (default: ${BOOTSTRAP_CONFIG_PATH})
  --release-name <name>        Helm release name (default: ${RELEASE_NAME})
  --namespace <name>           Kubernetes namespace (default: ${NAMESPACE})
  --kubeconfig <path>          Optional kubeconfig path
  --kube-context <context>     Optional kube context
  --cluster-name <name>        k3d cluster name for runtime setup and default kubeconfig lookup (default: ${CLUSTER_NAME})
  --values-file <path>         Extra values file path passed to the shared apply step (repeatable)
  --enable-service <name>      Enable a service for the shared apply step (repeatable)
  --disable-service <name>     Disable a service for the shared apply step (repeatable)
  --remote-docker-secret <n>   Override SSH secret name for OpenClaw remote Docker bootstrap
  --remote-docker-host <host>  Override OpenClaw remote Docker SSH host
  --remote-docker-port <port>  Override OpenClaw remote Docker SSH port
  --remote-docker-key <path>   Override OpenClaw remote Docker SSH private key path
  --incus-vm-name <name>       Incus VM name for runtime setup and remote Docker auto-discovery (default: ${INCUS_VM_NAME})
  --incus-connection-info <p>  Incus VM env file for remote Docker auto-discovery
  --shared-openclaw-state-source <path>
                                Host path shared with OpenClaw and the sandbox VM
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
    --cluster-name) CLUSTER_NAME="$2"; shift 2 ;;
    --values-file) VALUES_FILES+=("$2"); shift 2 ;;
    --enable-service) SET_ARGS+=(--enable-service "$2"); shift 2 ;;
    --disable-service) SET_ARGS+=(--disable-service "$2"); shift 2 ;;
    --remote-docker-secret) REMOTE_DOCKER_SECRET_NAME="$2"; shift 2 ;;
    --remote-docker-host) REMOTE_DOCKER_HOST="$2"; shift 2 ;;
    --remote-docker-port) REMOTE_DOCKER_PORT="$2"; shift 2 ;;
    --remote-docker-key) REMOTE_DOCKER_KEY_PATH="$2"; shift 2 ;;
    --incus-vm-name) INCUS_VM_NAME="$2"; shift 2 ;;
    --incus-connection-info) INCUS_CONNECTION_INFO_PATH="$2"; shift 2 ;;
    --shared-openclaw-state-source) SHARED_OPENCLAW_STATE_SOURCE="$2"; shift 2 ;;
    --verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$KUBECONFIG_PATH" ]]; then
  KUBECONFIG_PATH="$(normalize_kubeconfig_path "$RAW_KUBECONFIG")"
fi

case "$PROFILE" in
  k3d|k3s) ;;
  *) echo "Missing or unsupported --profile. Use k3d or k3s." >&2; usage; exit 1 ;;
esac

if [[ "$PROFILE" == "k3d" ]] && [[ -z "$KUBECONFIG_PATH" || "$KUBECONFIG_PATH" == "${HOME}/.kube/config" ]]; then
  KUBECONFIG_PATH="$(default_k3d_kubeconfig_path)"
fi

COMMON_ARGS=(
  --profile "$PROFILE"
  --bootstrap-config "$BOOTSTRAP_CONFIG_PATH"
  --release-name "$RELEASE_NAME"
  --namespace "$NAMESPACE"
)

if [[ -n "$KUBECONFIG_PATH" ]]; then
  COMMON_ARGS+=(--kubeconfig "$KUBECONFIG_PATH")
fi
if [[ -n "$KUBE_CONTEXT" ]]; then
  COMMON_ARGS+=(--kube-context "$KUBE_CONTEXT")
fi
if [[ -n "$REMOTE_DOCKER_SECRET_NAME" ]]; then
  COMMON_ARGS+=(--remote-docker-secret "$REMOTE_DOCKER_SECRET_NAME")
fi
if [[ -n "$REMOTE_DOCKER_HOST" ]]; then
  COMMON_ARGS+=(--remote-docker-host "$REMOTE_DOCKER_HOST")
fi
if [[ -n "$REMOTE_DOCKER_PORT" ]]; then
  COMMON_ARGS+=(--remote-docker-port "$REMOTE_DOCKER_PORT")
fi
if [[ -n "$REMOTE_DOCKER_KEY_PATH" ]]; then
  COMMON_ARGS+=(--remote-docker-key "$REMOTE_DOCKER_KEY_PATH")
fi
if [[ -n "$INCUS_VM_NAME" ]]; then
  COMMON_ARGS+=(--incus-vm-name "$INCUS_VM_NAME")
fi
if [[ -n "$INCUS_CONNECTION_INFO_PATH" ]]; then
  COMMON_ARGS+=(--incus-connection-info "$INCUS_CONNECTION_INFO_PATH")
fi
if [[ -n "$SHARED_OPENCLAW_STATE_SOURCE" ]]; then
  COMMON_ARGS+=(--shared-openclaw-state-source "$SHARED_OPENCLAW_STATE_SOURCE")
fi
if [[ "$VERBOSE" -eq 1 ]]; then
  COMMON_ARGS+=(--verbose)
fi

RUNTIME_CMD=()
case "$PROFILE" in
  k3d)
    RUNTIME_CMD=(
      ./scripts/bootstrap-runtime-k3d.sh
      --cluster-name "$CLUSTER_NAME"
      --bootstrap-config "$BOOTSTRAP_CONFIG_PATH"
      --release-name "$RELEASE_NAME"
      --namespace "$NAMESPACE"
    )
    if [[ -n "$KUBECONFIG_PATH" ]]; then
      RUNTIME_CMD+=(--kubeconfig "$KUBECONFIG_PATH")
    fi
    if [[ -n "$INCUS_VM_NAME" ]]; then
      RUNTIME_CMD+=(--incus-vm-name "$INCUS_VM_NAME")
    fi
    if [[ -n "$INCUS_CONNECTION_INFO_PATH" ]]; then
      RUNTIME_CMD+=(--incus-connection-info "$INCUS_CONNECTION_INFO_PATH")
    fi
    if [[ -n "$SHARED_OPENCLAW_STATE_SOURCE" ]]; then
      RUNTIME_CMD+=(--shared-openclaw-state-source "$SHARED_OPENCLAW_STATE_SOURCE")
    fi
    if [[ -n "$REMOTE_DOCKER_HOST" ]]; then
      RUNTIME_CMD+=(--remote-docker-host "$REMOTE_DOCKER_HOST")
    fi
    if [[ -n "$REMOTE_DOCKER_PORT" ]]; then
      RUNTIME_CMD+=(--remote-docker-port "$REMOTE_DOCKER_PORT")
    fi
    if [[ -n "$REMOTE_DOCKER_KEY_PATH" ]]; then
      RUNTIME_CMD+=(--remote-docker-key "$REMOTE_DOCKER_KEY_PATH")
    fi
    if [[ "$VERBOSE" -eq 1 ]]; then
      RUNTIME_CMD+=(--verbose)
    fi
    ;;
  k3s)
    RUNTIME_CMD=(
      ./scripts/bootstrap-runtime-k3s.sh
      --bootstrap-config "$BOOTSTRAP_CONFIG_PATH"
    )
    if [[ -n "$KUBECONFIG_PATH" ]]; then
      RUNTIME_CMD+=(--kubeconfig "$KUBECONFIG_PATH")
    fi
    if [[ -n "$INCUS_VM_NAME" ]]; then
      RUNTIME_CMD+=(--sandbox-vm-name "$INCUS_VM_NAME")
    fi
    if [[ -n "$SHARED_OPENCLAW_STATE_SOURCE" ]]; then
      RUNTIME_CMD+=(--openclaw-shared-state-dir "$SHARED_OPENCLAW_STATE_SOURCE")
    fi
    if [[ "$VERBOSE" -eq 1 ]]; then
      RUNTIME_CMD+=(--verbose)
    fi
    ;;
esac

APPLY_CMD=(./scripts/bootstrap-apply.sh "${COMMON_ARGS[@]}")
for values_file in "${VALUES_FILES[@]}"; do
  APPLY_CMD+=(--values-file "$values_file")
done
APPLY_CMD+=("${SET_ARGS[@]}")

SMOKE_CMD=(./scripts/bootstrap-smoke.sh "${COMMON_ARGS[@]}")
if [[ "$PROFILE" == "k3d" ]]; then
  SMOKE_CMD+=(--cluster-name "$CLUSTER_NAME")
fi

"${RUNTIME_CMD[@]}"
"${APPLY_CMD[@]}"
"${SMOKE_CMD[@]}"
