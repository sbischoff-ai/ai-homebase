#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/lib/logging.sh"
source "$(dirname "$0")/lib/bootstrap-hosts.sh"
source "$(dirname "$0")/lib/ingress-nginx.sh"

TARGET_USER="${TARGET_USER:-${SUDO_USER:-${USER}}}"
TARGET_HOME=""
BOOTSTRAP_CONFIG_PATH="${BOOTSTRAP_CONFIG_PATH:-bootstrap.local.toml}"
RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
K3S_CHANNEL="${K3S_CHANNEL:-stable}"
K3S_INSTALL_ARGS="${K3S_INSTALL_ARGS:---write-kubeconfig-mode 644 --disable=traefik}"
K3S_KUBECONFIG="${K3S_KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
K3S_CONFIG_DIR="${K3S_CONFIG_DIR:-/etc/rancher/k3s/config.yaml.d}"
K3S_CONFIG_PATH="${K3S_CONFIG_PATH:-${K3S_CONFIG_DIR}/10-ai-homebase.yaml}"
INCUS_BRIDGE_NAME="${INCUS_BRIDGE_NAME:-incusbr0}"
INCUS_BRIDGE_IPV4="${INCUS_BRIDGE_IPV4:-10.10.10.1/24}"
INCUS_STORAGE_POOL="${INCUS_STORAGE_POOL:-default}"
INCUS_STORAGE_DRIVER="${INCUS_STORAGE_DRIVER:-dir}"
INCUS_PROFILE_NAME="${INCUS_PROFILE_NAME:-default}"
OPENCLAW_SHARED_STATE_DIR="${OPENCLAW_SHARED_STATE_DIR:-/var/lib/ai-homebase/openclaw-state}"
SANDBOX_VM_NAME="${SANDBOX_VM_NAME:-openclaw-sandbox}"
SANDBOX_HOST_ALIAS="${SANDBOX_HOST_ALIAS:-openclaw-sandbox.homebase.internal}"
SANDBOX_SHARED_OPENCLAW_STATE_TARGET="${SANDBOX_SHARED_OPENCLAW_STATE_TARGET:-/home/node/.openclaw}"
SANDBOX_CONNECTION_INFO_PATH="${SANDBOX_CONNECTION_INFO_PATH:-}"
RUNNER_VM_NAME="${RUNNER_VM_NAME:-gitea-actions-runner}"
RUNNER_HOST_ALIAS="${RUNNER_HOST_ALIAS:-gitea-actions-runner.homebase.internal}"
RUNNER_SSH_PORT="${RUNNER_SSH_PORT:-2223}"
RUNNER_CONNECTION_INFO_PATH="${RUNNER_CONNECTION_INFO_PATH:-}"
RUNNER_SSH_KEY_PATH="${RUNNER_SSH_KEY_PATH:-}"
EXTRA_RESOLVE_HOSTS=()

usage() {
  cat <<USAGE
Usage: $0 [options]

Create or reconcile the ai-homebase k3s runtime and companion Incus VMs.

Options:
  --bootstrap-config <path>      Bootstrap config file used for hostnames and Gitea Actions settings (default: ${BOOTSTRAP_CONFIG_PATH})
  --release-name <name>          Helm release name used by Memgraph TCP forwarding (default: ${RELEASE_NAME})
  --namespace <name>             Kubernetes namespace used by Memgraph TCP forwarding (default: ${NAMESPACE})
  --target-user <name>           Operator user that owns Incus VM state and SSH keys (default: ${TARGET_USER})
  --k3s-channel <name>           k3s install channel used when k3s is missing (default: ${K3S_CHANNEL})
  --k3s-install-args <args>      Extra INSTALL_K3S_EXEC args used when k3s is installed (default: ${K3S_INSTALL_ARGS})
  --kubeconfig <path>            kubeconfig path for kubectl and Helm checks (default: ${K3S_KUBECONFIG})
  --incus-bridge-name <name>     Incus bridge name (default: ${INCUS_BRIDGE_NAME})
  --incus-bridge-ipv4 <cidr>     Incus bridge IPv4 CIDR (default: ${INCUS_BRIDGE_IPV4})
  --incus-storage-pool <name>    Incus storage pool name (default: ${INCUS_STORAGE_POOL})
  --incus-storage-driver <name>  Incus storage driver for a new pool (default: ${INCUS_STORAGE_DRIVER})
  --openclaw-shared-state-dir <path>
                                 Host path shared between k3s and the sandbox VM for OpenClaw state (default: ${OPENCLAW_SHARED_STATE_DIR})
  --sandbox-vm-name <name>       Incus sandbox VM name (default: ${SANDBOX_VM_NAME})
  --sandbox-host-alias <name>    Sandbox SSH host alias (default: ${SANDBOX_HOST_ALIAS})
  --resolve-host <name>          Additional hostname to resolve inside the sandbox and runner VMs (repeatable)
  --verbose                      Stream full command output
  -h, --help                     Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap-config) BOOTSTRAP_CONFIG_PATH="$2"; shift 2 ;;
    --release-name) RELEASE_NAME="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --target-user) TARGET_USER="$2"; shift 2 ;;
    --k3s-channel) K3S_CHANNEL="$2"; shift 2 ;;
    --k3s-install-args) K3S_INSTALL_ARGS="$2"; shift 2 ;;
    --kubeconfig) K3S_KUBECONFIG="$2"; shift 2 ;;
    --incus-bridge-name) INCUS_BRIDGE_NAME="$2"; shift 2 ;;
    --incus-bridge-ipv4) INCUS_BRIDGE_IPV4="$2"; shift 2 ;;
    --incus-storage-pool) INCUS_STORAGE_POOL="$2"; shift 2 ;;
    --incus-storage-driver) INCUS_STORAGE_DRIVER="$2"; shift 2 ;;
    --openclaw-shared-state-dir) OPENCLAW_SHARED_STATE_DIR="$2"; shift 2 ;;
    --sandbox-vm-name) SANDBOX_VM_NAME="$2"; shift 2 ;;
    --sandbox-host-alias) SANDBOX_HOST_ALIAS="$2"; shift 2 ;;
    --resolve-host) EXTRA_RESOLVE_HOSTS+=("$2"); shift 2 ;;
    --verbose) BOOTSTRAP_VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

bootstrap_init_logging
trap 'fail "k3s runtime bootstrap failed. Log: ${BOOTSTRAP_LOG_FILE}"' ERR

for cmd in curl getent helm id incus kubectl python3 systemctl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Missing required dependency: $cmd"
    exit 1
  fi
done
if [[ "${EUID}" -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
  fail "Missing required dependency: sudo"
  exit 1
fi
if [[ "${TARGET_USER}" == "root" ]]; then
  fail "Use a non-root target user so Incus VM state and SSH keys land in the operator's home directory."
  exit 1
fi
if ! id "${TARGET_USER}" >/dev/null 2>&1; then
  fail "Target user '${TARGET_USER}' does not exist on this host."
  exit 1
fi

TARGET_UID="$(id -u "${TARGET_USER}")"
TARGET_GID="$(id -g "${TARGET_USER}")"
TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
if [[ -z "${TARGET_HOME}" ]]; then
  fail "Unable to determine home directory for ${TARGET_USER}."
  exit 1
fi

if [[ -z "${SANDBOX_CONNECTION_INFO_PATH}" ]]; then
  SANDBOX_CONNECTION_INFO_PATH="${TARGET_HOME}/.local/state/ai-homebase/incus/${SANDBOX_VM_NAME}.env"
fi

bootstrap_load_shell_vars "${BOOTSTRAP_CONFIG_PATH}"
RUNNER_VM_NAME="${GITEA_ACTIONS_RUNNER_VM_NAME:-${RUNNER_VM_NAME}}"
RUNNER_HOST_ALIAS="${GITEA_ACTIONS_RUNNER_HOST_ALIAS:-${RUNNER_HOST_ALIAS}}"
RUNNER_SSH_PORT="${GITEA_ACTIONS_RUNNER_SSH_PORT:-${RUNNER_SSH_PORT}}"
if [[ -z "${RUNNER_CONNECTION_INFO_PATH}" ]]; then
  RUNNER_CONNECTION_INFO_PATH="${TARGET_HOME}/.local/state/ai-homebase/incus/${RUNNER_VM_NAME}.env"
fi
if [[ -z "${RUNNER_SSH_KEY_PATH}" ]]; then
  RUNNER_SSH_KEY_PATH="${TARGET_HOME}/.local/state/ai-homebase/incus/${RUNNER_VM_NAME}-id_ed25519"
fi

KUBECTL_ARGS=(--kubeconfig "${K3S_KUBECONFIG}")
HELM_ARGS=(--kubeconfig "${K3S_KUBECONFIG}")

as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

run_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    run_quiet "$@"
  else
    run_quiet sudo "$@"
  fi
}

run_root_write_file() {
  local destination="$1"
  local content="$2"

  if [[ "${EUID}" -eq 0 ]]; then
    printf '%s\n' "${content}" | tee "${destination}" >/dev/null
  else
    printf '%s\n' "${content}" | sudo tee "${destination}" >/dev/null
  fi >>"${BOOTSTRAP_LOG_FILE}" 2>&1
}

run_root_install_k3s() {
  if [[ "${EUID}" -eq 0 ]]; then
    env INSTALL_K3S_CHANNEL="${K3S_CHANNEL}" INSTALL_K3S_EXEC="${K3S_INSTALL_ARGS}" \
      sh -c 'curl -fsSL https://get.k3s.io | sh -' >>"${BOOTSTRAP_LOG_FILE}" 2>&1
  else
    sudo env INSTALL_K3S_CHANNEL="${K3S_CHANNEL}" INSTALL_K3S_EXEC="${K3S_INSTALL_ARGS}" \
      sh -c 'curl -fsSL https://get.k3s.io | sh -' >>"${BOOTSTRAP_LOG_FILE}" 2>&1
  fi
}

wait_for_k3s_node_ready() {
  local deadline nodes
  local -a node_names

  deadline=$((SECONDS + 180))
  while [[ "${SECONDS}" -lt "${deadline}" ]]; do
    nodes="$(kubectl "${KUBECTL_ARGS[@]}" get nodes -o name 2>>"${BOOTSTRAP_LOG_FILE}" || true)"
    if [[ -n "${nodes}" ]]; then
      mapfile -t node_names <<<"${nodes}"
      run_quiet kubectl "${KUBECTL_ARGS[@]}" wait --for=condition=Ready "${node_names[@]}" --timeout=180s
      return 0
    fi
    sleep 2
  done

  fail "Timed out waiting for k3s node registration. Check k3s service logs with: sudo journalctl -u k3s -n 100 --no-pager"
  return 1
}

run_as_target_user() {
  if [[ "${EUID}" -eq 0 ]]; then
    run_quiet sudo -u "${TARGET_USER}" -H env HOME="${TARGET_HOME}" PATH="${PATH}" "$@"
  elif [[ "${USER}" == "${TARGET_USER}" ]]; then
    run_quiet "$@"
  else
    run_quiet sudo -u "${TARGET_USER}" -H env HOME="${TARGET_HOME}" PATH="${PATH}" "$@"
  fi
}

step "Reconciling shared OpenClaw state directory"
run_root install -d -m 0775 -o "${TARGET_UID}" -g "${TARGET_GID}" "${OPENCLAW_SHARED_STATE_DIR}"

step "Reconciling k3s config"
run_root install -d -m 0755 "${K3S_CONFIG_DIR}"
run_root_write_file "${K3S_CONFIG_PATH}" 'write-kubeconfig-mode: "644"
disable:
  - traefik'

if ! command -v k3s >/dev/null 2>&1; then
  step "Installing k3s"
  run_root_install_k3s
  ok "k3s installed"
else
  ok "k3s is already installed"
fi

step "Ensuring k3s service is running"
run_root systemctl enable --now k3s
run_root systemctl restart k3s

step "Waiting for the k3s node to become Ready"
wait_for_k3s_node_ready

if kubectl "${KUBECTL_ARGS[@]}" -n kube-system get deployment traefik >/dev/null 2>&1; then
  fail "This bootstrap expects k3s without the bundled Traefik add-on. Remove Traefik before continuing."
  exit 1
fi
ok "Traefik is absent"

MEMGRAPH_TCP_NAMESPACE="$NAMESPACE" MEMGRAPH_TCP_RELEASE_NAME="$RELEASE_NAME" ensure_ingress_nginx

step "Ensuring Incus service is running"
run_root systemctl enable --now incus

if ! as_root incus profile show "${INCUS_PROFILE_NAME}" >/dev/null 2>&1; then
  step "Initializing Incus"
  run_root incus admin init --auto
fi

if ! as_root incus network show "${INCUS_BRIDGE_NAME}" >/dev/null 2>&1; then
  step "Creating Incus bridge ${INCUS_BRIDGE_NAME}"
  run_root incus network create "${INCUS_BRIDGE_NAME}" \
    ipv4.address="${INCUS_BRIDGE_IPV4}" \
    ipv4.nat=true \
    ipv6.address=none
else
  ok "Incus bridge ${INCUS_BRIDGE_NAME} already exists"
fi

if ! as_root incus storage show "${INCUS_STORAGE_POOL}" >/dev/null 2>&1; then
  step "Creating Incus storage pool ${INCUS_STORAGE_POOL}"
  run_root incus storage create "${INCUS_STORAGE_POOL}" "${INCUS_STORAGE_DRIVER}"
else
  ok "Incus storage pool ${INCUS_STORAGE_POOL} already exists"
fi

if ! as_root incus profile device get "${INCUS_PROFILE_NAME}" root pool >/dev/null 2>&1; then
  step "Attaching root disk device to Incus profile ${INCUS_PROFILE_NAME}"
  run_root incus profile device add "${INCUS_PROFILE_NAME}" root disk path=/ pool="${INCUS_STORAGE_POOL}"
else
  ok "Incus profile ${INCUS_PROFILE_NAME} already has a root disk"
fi

if ! as_root incus profile device get "${INCUS_PROFILE_NAME}" eth0 network >/dev/null 2>&1; then
  step "Attaching NIC device to Incus profile ${INCUS_PROFILE_NAME}"
  run_root incus profile device add "${INCUS_PROFILE_NAME}" eth0 nic network="${INCUS_BRIDGE_NAME}" name=eth0
else
  ok "Incus profile ${INCUS_PROFILE_NAME} already has a network device"
fi

step "Reconciling the OpenClaw sandbox VM"
SANDBOX_VM_CMD=(
  ./scripts/incus-vm-up.sh
  --vm-name "${SANDBOX_VM_NAME}"
  --host-alias "${SANDBOX_HOST_ALIAS}"
  --shared-openclaw-state-source "${OPENCLAW_SHARED_STATE_DIR}"
  --shared-openclaw-state-target "${SANDBOX_SHARED_OPENCLAW_STATE_TARGET}"
)
append_bootstrap_resolve_hosts SANDBOX_VM_CMD
for resolve_host in "${EXTRA_RESOLVE_HOSTS[@]}"; do
  SANDBOX_VM_CMD+=(--resolve-host "${resolve_host}")
done
run_as_target_user "${SANDBOX_VM_CMD[@]}"
ok "Sandbox VM is ready"

if [[ "${GITEA_ACTIONS_ENABLED:-false}" == "true" ]]; then
  step "Reconciling the Gitea Actions runner VM"
  RUNNER_VM_CMD=(
    ./scripts/incus-vm-up.sh
    --vm-name "${RUNNER_VM_NAME}"
    --host-alias "${RUNNER_HOST_ALIAS}"
    --ssh-host-port "${RUNNER_SSH_PORT}"
    --ssh-key-path "${RUNNER_SSH_KEY_PATH}"
    --remote-user-gecos "Gitea Actions runner Docker user"
  )
  append_bootstrap_resolve_hosts RUNNER_VM_CMD
  for resolve_host in "${EXTRA_RESOLVE_HOSTS[@]}"; do
    RUNNER_VM_CMD+=(--resolve-host "${resolve_host}")
  done
  run_as_target_user "${RUNNER_VM_CMD[@]}"
  ok "Gitea Actions runner VM is ready"
fi

echo
echo "k3s runtime is ready."
echo "Summary:"
echo "  Target user: ${TARGET_USER}"
echo "  kubeconfig: ${K3S_KUBECONFIG}"
echo "  Shared OpenClaw state dir: ${OPENCLAW_SHARED_STATE_DIR}"
echo "  Sandbox VM: ${SANDBOX_VM_NAME}"
echo "  Sandbox connection info: ${SANDBOX_CONNECTION_INFO_PATH}"
if [[ "${GITEA_ACTIONS_ENABLED:-false}" == "true" ]]; then
  echo "  Gitea Actions runner VM: ${RUNNER_VM_NAME}"
  echo "  Runner connection info: ${RUNNER_CONNECTION_INFO_PATH}"
fi
echo "  Next step: ./scripts/bootstrap-stack.sh --profile k3s --bootstrap-config ${BOOTSTRAP_CONFIG_PATH} --shared-openclaw-state-source ${OPENCLAW_SHARED_STATE_DIR}"
echo "  Bootstrap log: ${BOOTSTRAP_LOG_FILE}"
