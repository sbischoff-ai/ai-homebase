#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/lib/logging.sh"

VM_NAME="${VM_NAME:-openclaw-sandbox}"
REMOTE_USER="${REMOTE_USER:-docker-remote}"
SSH_HOST_PORT="${SSH_HOST_PORT:-2222}"
CPU_LIMIT="${CPU_LIMIT:-2}"
MEMORY_LIMIT="${MEMORY_LIMIT:-6GiB}"
DISK_SIZE="${DISK_SIZE:-12GiB}"
INCUS_IMAGE="${INCUS_IMAGE:-images:debian/12/cloud}"
INCUS_NETWORK="${INCUS_NETWORK:-incusbr0}"
STATE_DIR="${STATE_DIR:-${HOME}/.local/state/ai-homebase/incus}"
SSH_KEY_PATH="${SSH_KEY_PATH:-${STATE_DIR}/${VM_NAME}-id_ed25519}"
HOST_ALIAS="${HOST_ALIAS:-host.k3d.internal}"
VM_STATIC_IPV4="${VM_STATIC_IPV4:-}"
HOST_LISTEN_ADDRESS="${HOST_LISTEN_ADDRESS:-}"
CONNECTION_INFO_PATH="${CONNECTION_INFO_PATH:-}"

usage() {
  cat <<USAGE
Usage: $0 [options]

Create or reuse the dedicated Incus VM used as a small remote Docker sandbox for OpenClaw.

Options:
  --vm-name <name>           Incus instance name (default: ${VM_NAME})
  --remote-user <name>       SSH user inside the VM (default: ${REMOTE_USER})
  --ssh-host-port <port>     Host TCP port proxied to guest SSH 22 (default: ${SSH_HOST_PORT})
  --cpu <count>              CPU allowance for the VM (default: ${CPU_LIMIT})
  --memory <size>            Memory limit for the VM (default: ${MEMORY_LIMIT})
  --disk-size <size>         Root disk size (default: ${DISK_SIZE})
  --image <remote:image>     Incus image to use (default: ${INCUS_IMAGE})
  --network <name>           Incus network/bridge (default: ${INCUS_NETWORK})
  --state-dir <path>         Local state dir for generated SSH keys (default: ${STATE_DIR})
  --ssh-key-path <path>      SSH key path for remote Docker access (default: ${SSH_KEY_PATH})
  --host-alias <name>        Hostname pods should use for the proxied SSH endpoint (default: ${HOST_ALIAS})
  --host-listen-address <ip> Concrete Incus-host IPv4 for the NAT proxy listener (default: auto-detect from ${INCUS_NETWORK})
  --vm-static-ipv4 <ip>      Stable VM IPv4 for NAT proxying (default: auto-derive from ${INCUS_NETWORK})
  --verbose                  Stream full command output
  -h, --help                 Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vm-name) VM_NAME="$2"; shift 2 ;;
    --remote-user) REMOTE_USER="$2"; shift 2 ;;
    --ssh-host-port) SSH_HOST_PORT="$2"; shift 2 ;;
    --cpu) CPU_LIMIT="$2"; shift 2 ;;
    --memory) MEMORY_LIMIT="$2"; shift 2 ;;
    --disk-size) DISK_SIZE="$2"; shift 2 ;;
    --image) INCUS_IMAGE="$2"; shift 2 ;;
    --network) INCUS_NETWORK="$2"; shift 2 ;;
    --state-dir) STATE_DIR="$2"; shift 2 ;;
    --ssh-key-path) SSH_KEY_PATH="$2"; shift 2 ;;
    --host-alias) HOST_ALIAS="$2"; shift 2 ;;
    --host-listen-address) HOST_LISTEN_ADDRESS="$2"; shift 2 ;;
    --vm-static-ipv4) VM_STATIC_IPV4="$2"; shift 2 ;;
    --verbose) BOOTSTRAP_VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$CONNECTION_INFO_PATH" ]]; then
  CONNECTION_INFO_PATH="${STATE_DIR}/${VM_NAME}.env"
fi

bootstrap_init_logging
trap 'fail "Incus VM setup failed. Log: ${BOOTSTRAP_LOG_FILE}"' ERR

for cmd in incus python3 ssh-keygen; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Missing required dependency: $cmd"
    exit 1
  fi
done

run_checked() {
  run_quiet "$@"
}

instance_exists() {
  incus info "$VM_NAME" >/dev/null 2>&1
}

instance_running() {
  [[ "$(incus list "$VM_NAME" -f csv -c s 2>/dev/null || true)" == "RUNNING" ]]
}

instance_has_local_device() {
  local device_name="$1"
  incus config show "$VM_NAME" 2>/dev/null | awk -v device_name="$device_name" '
    BEGIN { in_devices = 0 }
    /^devices:$/ { in_devices = 1; next }
    /^[^ ]/ {
      if (in_devices) {
        exit found ? 0 : 1
      }
    }
    in_devices && $0 == "  " device_name ":" { found = 1 }
    END { exit found ? 0 : 1 }
  '
}

get_vm_ipv4() {
  incus list "$VM_NAME" -f json | python3 -c '
import json
import sys

items = json.load(sys.stdin)
if not items:
    raise SystemExit(1)
state = items[0].get("state") or {}
network = state.get("network") or {}
for details in network.values():
    for address in details.get("addresses") or []:
        if address.get("family") == "inet" and address.get("scope") == "global":
            print(address.get("address"))
            raise SystemExit(0)
raise SystemExit(1)
'
}

get_network_ipv4_cidr() {
  incus network get "$INCUS_NETWORK" ipv4.address 2>/dev/null
}

derive_host_address_from_cidr() {
  local cidr="$1"
  python3 - "$cidr" <<'PY'
import ipaddress
import sys

interface = ipaddress.ip_interface(sys.argv[1])
print(interface.ip)
PY
}

derive_vm_static_ipv4_from_cidr() {
  local cidr="$1"
  local vm_name="$2"
  python3 - "$cidr" "$vm_name" <<'PY'
import hashlib
import ipaddress
import sys

interface = ipaddress.ip_interface(sys.argv[1])
network = interface.network
usable_hosts = network.num_addresses - 2
if usable_hosts < 8:
    raise SystemExit(1)

seed = int(hashlib.sha256(sys.argv[2].encode()).hexdigest()[:8], 16)
offset = 10 + (seed % max(1, usable_hosts - 10))
candidate = network.network_address + offset
if candidate == interface.ip:
    candidate += 1

print(candidate)
PY
}

autodetect_network_addresses() {
  local network_cidr

  network_cidr="$(get_network_ipv4_cidr)"
  if [[ -z "$network_cidr" || "$network_cidr" == "none" ]]; then
    fail "Unable to determine IPv4 configuration for Incus network ${INCUS_NETWORK}"
    exit 1
  fi

  if [[ -z "$HOST_LISTEN_ADDRESS" ]]; then
    HOST_LISTEN_ADDRESS="$(derive_host_address_from_cidr "$network_cidr")"
  fi

  if [[ -z "$VM_STATIC_IPV4" ]]; then
    VM_STATIC_IPV4="$(derive_vm_static_ipv4_from_cidr "$network_cidr" "$VM_NAME")"
  fi
}

wait_for_vm_network() {
  local deadline=$((SECONDS + 180))
  while [[ $SECONDS -lt $deadline ]]; do
    if VM_IPV4="$(get_vm_ipv4 2>/dev/null)"; then
      export VM_IPV4
      return 0
    fi
    sleep 3
  done

  fail "Timed out waiting for ${VM_NAME} to receive an IPv4 address"
  exit 1
}

ensure_ssh_key() {
  run_checked mkdir -p "$STATE_DIR"
  if [[ ! -f "$SSH_KEY_PATH" ]]; then
    step "Generating SSH key for remote Docker access"
    run_checked ssh-keygen -t ed25519 -N '' -f "$SSH_KEY_PATH"
    ok "Generated SSH key at ${SSH_KEY_PATH}"
  fi
}

render_cloud_init() {
  local template_path="$(cd "$(dirname "$0")/.." && pwd)/incus/openclaw-sandbox-user-data.tpl"
  local rendered_path
  rendered_path="$(mktemp /tmp/${VM_NAME}-cloud-init.XXXXXX.yaml)"

  python3 - "$template_path" "$rendered_path" "$VM_NAME" "$REMOTE_USER" "$SSH_KEY_PATH.pub" <<'PY'
import pathlib
import sys

template_path = pathlib.Path(sys.argv[1])
rendered_path = pathlib.Path(sys.argv[2])
vm_name = sys.argv[3]
remote_user = sys.argv[4]
ssh_pubkey_path = pathlib.Path(sys.argv[5])

text = template_path.read_text()
ssh_key = ssh_pubkey_path.read_text().strip()
rendered = (text
    .replace("__VM_NAME__", vm_name)
    .replace("__REMOTE_USER__", remote_user)
    .replace("__SSH_PUBLIC_KEY__", ssh_key))
rendered_path.write_text(rendered)
PY

  echo "$rendered_path"
}

ensure_proxy_device() {
  if incus config device show "$VM_NAME" | grep -q '^ssh-proxy:'; then
    run_checked incus config device set "$VM_NAME" ssh-proxy listen "tcp:${HOST_LISTEN_ADDRESS}:${SSH_HOST_PORT}"
    run_checked incus config device set "$VM_NAME" ssh-proxy connect tcp:0.0.0.0:22
    run_checked incus config device set "$VM_NAME" ssh-proxy nat true
  else
    run_checked incus config device add "$VM_NAME" ssh-proxy proxy \
      listen="tcp:${HOST_LISTEN_ADDRESS}:${SSH_HOST_PORT}" \
      connect="tcp:0.0.0.0:22" \
      nat=true
  fi
}

ensure_vm_static_ip() {
  if instance_has_local_device eth0; then
    run_checked incus config device set "$VM_NAME" eth0 ipv4.address "$VM_STATIC_IPV4"
  else
    run_checked incus config device override "$VM_NAME" eth0 "ipv4.address=${VM_STATIC_IPV4}"
  fi
}

ensure_root_disk_size() {
  if instance_has_local_device root; then
    run_checked incus config device set "$VM_NAME" root size "$DISK_SIZE"
  else
    run_checked incus config device override "$VM_NAME" root "size=${DISK_SIZE}"
  fi
}

write_connection_info() {
  cat >"$CONNECTION_INFO_PATH" <<EOF
HOST_ALIAS=${HOST_ALIAS}
HOST_LISTEN_ADDRESS=${HOST_LISTEN_ADDRESS}
SSH_HOST_PORT=${SSH_HOST_PORT}
REMOTE_USER=${REMOTE_USER}
VM_STATIC_IPV4=${VM_STATIC_IPV4}
DOCKER_HOST=ssh://${REMOTE_USER}@${HOST_LISTEN_ADDRESS}:${SSH_HOST_PORT}
EOF
}

ensure_ssh_key
CLOUD_INIT_FILE="$(render_cloud_init)"
trap 'rm -f "${CLOUD_INIT_FILE:-}"' EXIT

if instance_exists; then
  step "Reusing existing Incus VM ${VM_NAME}"
else
  step "Creating Incus VM ${VM_NAME} from ${INCUS_IMAGE}"
  run_checked incus init "$INCUS_IMAGE" "$VM_NAME" --vm --network "$INCUS_NETWORK" --device "root,size=${DISK_SIZE}"
  ok "Created Incus VM ${VM_NAME}"
fi

run_checked incus config set "$VM_NAME" limits.cpu "$CPU_LIMIT"
run_checked incus config set "$VM_NAME" limits.memory "$MEMORY_LIMIT"
if [[ "${BOOTSTRAP_VERBOSE:-0}" == "1" ]]; then
  incus config set "$VM_NAME" user.user-data="$(cat "$CLOUD_INIT_FILE")"
else
  incus config set "$VM_NAME" user.user-data="$(cat "$CLOUD_INIT_FILE")" >>"$BOOTSTRAP_LOG_FILE" 2>&1
fi
autodetect_network_addresses
ensure_root_disk_size
ensure_vm_static_ip
ensure_proxy_device

if ! instance_running; then
  step "Starting Incus VM ${VM_NAME}"
  run_checked incus start "$VM_NAME"
else
  step "Incus VM ${VM_NAME} is already running"
fi

step "Waiting for Incus VM networking"
wait_for_vm_network
ok "Incus VM ${VM_NAME} has IPv4 ${VM_IPV4}"

write_connection_info

echo "Incus VM ready"
echo "  Name: ${VM_NAME}"
echo "  Guest IP: ${VM_IPV4}"
echo "  VM static IPv4: ${VM_STATIC_IPV4}"
echo "  SSH proxy endpoint (host alias): ssh://${REMOTE_USER}@${HOST_ALIAS}:${SSH_HOST_PORT}"
echo "  SSH proxy listen address: ${HOST_LISTEN_ADDRESS}:${SSH_HOST_PORT}"
echo "  SSH key: ${SSH_KEY_PATH}"
echo "  Docker host hint: DOCKER_HOST=ssh://${REMOTE_USER}@${HOST_LISTEN_ADDRESS}:${SSH_HOST_PORT}"
echo "  Connection info: ${CONNECTION_INFO_PATH}"
echo "  Bootstrap log: ${BOOTSTRAP_LOG_FILE}"
