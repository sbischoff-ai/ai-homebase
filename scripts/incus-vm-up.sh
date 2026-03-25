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
RESOLVE_HOSTS=()
INCUS_NETWORK_IPV4_CIDR="${INCUS_NETWORK_IPV4_CIDR:-}"
INCUS_NETWORK_BRIDGE_IPV4="${INCUS_NETWORK_BRIDGE_IPV4:-}"
INCUS_NETWORK_IPV4_NAT="${INCUS_NETWORK_IPV4_NAT:-}"
INCUS_NETWORK_DNS_NAMESERVERS="${INCUS_NETWORK_DNS_NAMESERVERS:-}"
INCUS_NETWORK_DNS_MODE="${INCUS_NETWORK_DNS_MODE:-}"
INCUS_NETWORK_MANAGED="${INCUS_NETWORK_MANAGED:-}"
INCUS_NETWORK_TYPE="${INCUS_NETWORK_TYPE:-}"
INCUS_NETWORK_DNS_STRATEGY="${INCUS_NETWORK_DNS_STRATEGY:-}"
CONNECTION_INFO_PATH="${CONNECTION_INFO_PATH:-}"
SSH_READY_TIMEOUT_SECONDS="${SSH_READY_TIMEOUT_SECONDS:-600}"
READINESS_FAILURE_REASON=""

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
  --resolve-host <name>      Guest/container hostname to resolve to the Incus host listener address (repeatable)
  --vm-static-ipv4 <ip>      Stable VM IPv4 for NAT proxying (default: auto-derive from ${INCUS_NETWORK})
  --ssh-ready-timeout-seconds <seconds>
                             Wait time for the VM SSH endpoint to become reachable (default: ${SSH_READY_TIMEOUT_SECONDS})
  --verbose                  Stream full command output
  -h, --help                 Show this help message

Environment:
  SSH_READY_TIMEOUT_SECONDS  Same as --ssh-ready-timeout-seconds; first boot may need several minutes
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
    --resolve-host) RESOLVE_HOSTS+=("$2"); shift 2 ;;
    --vm-static-ipv4) VM_STATIC_IPV4="$2"; shift 2 ;;
    --ssh-ready-timeout-seconds) SSH_READY_TIMEOUT_SECONDS="$2"; shift 2 ;;
    --verbose) BOOTSTRAP_VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$CONNECTION_INFO_PATH" ]]; then
  CONNECTION_INFO_PATH="${STATE_DIR}/${VM_NAME}.env"
fi

if ! [[ "$SSH_READY_TIMEOUT_SECONDS" =~ ^[0-9]+$ ]]; then
  fail "SSH_READY_TIMEOUT_SECONDS must be a non-negative integer"
  exit 1
fi

bootstrap_init_logging
trap 'fail "Incus VM setup failed. Log: ${BOOTSTRAP_LOG_FILE}"' ERR

for cmd in incus python3 ssh ssh-keygen; do
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

get_vm_eth0_hwaddr() {
  incus config show "$VM_NAME" 2>/dev/null \
    | awk -F': ' '$1 == "  volatile.eth0.hwaddr" { print $2; exit }' \
    | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"
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

get_network_ipv4_nat() {
  incus network get "$INCUS_NETWORK" ipv4.nat 2>/dev/null || true
}

get_network_dns_nameservers() {
  incus network get "$INCUS_NETWORK" dns.nameservers 2>/dev/null || true
}

get_network_dns_mode() {
  incus network get "$INCUS_NETWORK" dns.mode 2>/dev/null || true
}

get_network_show_field() {
  local field_name="$1"
  incus network show "$INCUS_NETWORK" 2>/dev/null | awk -F': ' -v field_name="$field_name" '
    $1 == field_name {
      print $2
      exit
    }
  '
}

trim_network_value() {
  local raw_value="${1:-}"
  raw_value="${raw_value#"${raw_value%%[![:space:]]*}"}"
  raw_value="${raw_value%"${raw_value##*[![:space:]]}"}"
  if [[ -z "$raw_value" ]]; then
    return 0
  fi
  printf '%s\n' "$raw_value"
}

derive_ipv4_from_cidr() {
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

normalize_resolve_hosts() {
  local normalized=()
  local candidate=""
  local -A seen=()

  if [[ -n "$HOST_ALIAS" ]]; then
    RESOLVE_HOSTS+=("$HOST_ALIAS")
  fi

  for candidate in "${RESOLVE_HOSTS[@]}"; do
    candidate="${candidate,,}"
    candidate="${candidate#"${candidate%%[![:space:]]*}"}"
    candidate="${candidate%"${candidate##*[![:space:]]}"}"
    [[ -n "$candidate" ]] || continue
    if [[ ! "$candidate" =~ ^[a-z0-9.-]+$ ]]; then
      fail "Invalid --resolve-host value: ${candidate}. Expected a DNS hostname containing only [a-z0-9.-]."
      exit 1
    fi
    if [[ -n "${seen[$candidate]:-}" ]]; then
      continue
    fi
    seen[$candidate]=1
    normalized+=("$candidate")
  done

  RESOLVE_HOSTS=("${normalized[@]}")
}

autodetect_network_addresses() {
  if [[ -z "$INCUS_NETWORK_IPV4_CIDR" ]]; then
    INCUS_NETWORK_IPV4_CIDR="$(get_network_ipv4_cidr)"
  fi
  if [[ -z "$INCUS_NETWORK_IPV4_CIDR" || "$INCUS_NETWORK_IPV4_CIDR" == "none" ]]; then
    fail "Unable to determine IPv4 configuration for Incus network ${INCUS_NETWORK}"
    exit 1
  fi

  if [[ -z "$HOST_LISTEN_ADDRESS" ]]; then
    HOST_LISTEN_ADDRESS="$(derive_ipv4_from_cidr "$INCUS_NETWORK_IPV4_CIDR")"
  fi

  if [[ -z "$INCUS_NETWORK_BRIDGE_IPV4" ]]; then
    INCUS_NETWORK_BRIDGE_IPV4="$(derive_ipv4_from_cidr "$INCUS_NETWORK_IPV4_CIDR")"
  fi

  if [[ -z "$VM_STATIC_IPV4" ]]; then
    VM_STATIC_IPV4="$(derive_vm_static_ipv4_from_cidr "$INCUS_NETWORK_IPV4_CIDR" "$VM_NAME")"
  fi

  if [[ -z "$INCUS_NETWORK_DNS_NAMESERVERS" ]]; then
    INCUS_NETWORK_DNS_NAMESERVERS="$(get_network_dns_nameservers)"
  fi
  if [[ -z "$INCUS_NETWORK_IPV4_NAT" ]]; then
    INCUS_NETWORK_IPV4_NAT="$(trim_network_value "$(get_network_ipv4_nat)")"
  fi
  if [[ -z "$INCUS_NETWORK_DNS_MODE" ]]; then
    INCUS_NETWORK_DNS_MODE="$(trim_network_value "$(get_network_dns_mode)")"
  fi
  if [[ -z "$INCUS_NETWORK_MANAGED" ]]; then
    INCUS_NETWORK_MANAGED="$(trim_network_value "$(get_network_show_field managed)")"
  fi
  if [[ -z "$INCUS_NETWORK_TYPE" ]]; then
    INCUS_NETWORK_TYPE="$(trim_network_value "$(get_network_show_field type)")"
  fi
}

validate_network_dns_strategy() {
  local normalized_nameservers=""
  local dns_source_description=""

  normalized_nameservers="$(
    python3 - "$INCUS_NETWORK_DNS_NAMESERVERS" <<'PY'
import re
import sys

entries = [
    entry.strip()
    for entry in re.split(r"[\s,]+", sys.argv[1])
    if entry.strip() and entry.strip().lower() != "none"
]
print(",".join(entries))
PY
  )"

  if [[ -n "$normalized_nameservers" ]]; then
    dns_source_description="explicit resolvers from ${INCUS_NETWORK}.dns.nameservers (${normalized_nameservers})"
    INCUS_NETWORK_DNS_STRATEGY="${dns_source_description}"
  else
    warn "Incus network ${INCUS_NETWORK} has an empty dns.nameservers setting; falling back to bridge gateway ${INCUS_NETWORK_BRIDGE_IPV4} for guest DNS. Ensure this bridge provides DNS service to guests or cloud-init package installation may fail."

    if [[ "${INCUS_NETWORK_DNS_MODE}" == "none" ]]; then
      fail "Incus network ${INCUS_NETWORK} is incompatible with guest DNS fallback: dns.nameservers is empty and dns.mode=none, so guests cannot rely on bridge gateway ${INCUS_NETWORK_BRIDGE_IPV4} for DNS. Configure ${INCUS_NETWORK} to provide bridge DNS or set dns.nameservers explicitly before rerunning ${0##*/}."
      exit 1
    fi

    if [[ -n "${INCUS_NETWORK_MANAGED}" && "${INCUS_NETWORK_MANAGED}" != "true" ]]; then
      fail "Incus network ${INCUS_NETWORK} is incompatible with guest DNS fallback: dns.nameservers is empty and the network is not managed by Incus, so bridge gateway ${INCUS_NETWORK_BRIDGE_IPV4} is not a safe DNS assumption. Configure guest-reachable DNS resolvers with 'incus network set ${INCUS_NETWORK} dns.nameservers <ip[,ip...]>' or use a managed bridge that serves DNS."
      exit 1
    fi

    dns_source_description="bridge gateway fallback via ${INCUS_NETWORK_BRIDGE_IPV4}"
    INCUS_NETWORK_DNS_STRATEGY="${dns_source_description}"
  fi

  step "Resolved guest DNS strategy: ${INCUS_NETWORK_DNS_STRATEGY}"
  step "Incus network ${INCUS_NETWORK} details: ipv4.address=${INCUS_NETWORK_IPV4_CIDR}, ipv4.nat=${INCUS_NETWORK_IPV4_NAT:-unknown}, dns.nameservers=${INCUS_NETWORK_DNS_NAMESERVERS:-<empty>}, dns.mode=${INCUS_NETWORK_DNS_MODE:-unknown}, managed=${INCUS_NETWORK_MANAGED:-unknown}, type=${INCUS_NETWORK_TYPE:-unknown}"
}

cloud_init_status_is_done() {
  local cloud_init_output="$1"
  grep -Eq 'status:[[:space:]]*done([[:space:]]|$)' <<<"$cloud_init_output"
}

cloud_init_status_is_failure() {
  local cloud_init_output="$1"
  grep -Eiq 'status:[[:space:]]*(error|failed|disabled|disabled-by-generator)([[:space:]]|$)' <<<"$cloud_init_output" \
    || grep -Eiq 'status:[[:space:]]*degraded([[:space:]]+done)?([[:space:]]|$)' <<<"$cloud_init_output"
}

fail_vm_readiness() {
  collect_readiness_diagnostics
  case "${READINESS_FAILURE_REASON:-guest-agent-unreachable}" in
    cloud-init-failed)
      fail "Failed waiting for ${VM_NAME}: cloud-init failed inside the guest before the SSH proxy at ${HOST_LISTEN_ADDRESS}:${SSH_HOST_PORT} became reachable. See timeout diagnostics in ${BOOTSTRAP_LOG_FILE}"
      ;;
    ssh-proxy-unreachable)
      fail "Timed out waiting for ${VM_NAME}: cloud-init completed but failed to connect to the SSH proxy at ${HOST_LISTEN_ADDRESS}:${SSH_HOST_PORT}. See timeout diagnostics in ${BOOTSTRAP_LOG_FILE}"
      ;;
    cloud-init-incomplete)
      fail "Timed out waiting for ${VM_NAME}: guest agent became reachable, but failed to observe cloud-init completion before the SSH proxy at ${HOST_LISTEN_ADDRESS}:${SSH_HOST_PORT} became reachable. See timeout diagnostics in ${BOOTSTRAP_LOG_FILE}"
      ;;
    *)
      fail "Timed out waiting for ${VM_NAME}: failed to reach the guest agent and failed to connect to the SSH proxy at ${HOST_LISTEN_ADDRESS}:${SSH_HOST_PORT}. See timeout diagnostics in ${BOOTSTRAP_LOG_FILE}"
      ;;
  esac
  exit 1
}

wait_for_vm_readiness() {
  local deadline=$((SECONDS + SSH_READY_TIMEOUT_SECONDS))
  local guest_agent_reachable_reported=0
  local guest_agent_unavailable_reported=0
  local cloud_init_wait_reported=0
  local ssh_proxy_wait_reported=0
  local cloud_init_output=""
  while [[ $SECONDS -lt $deadline ]]; do
    if VM_IPV4="$(get_vm_ipv4 2>/dev/null)"; then
      export VM_IPV4
    else
      VM_IPV4=""
      export VM_IPV4
    fi

    if ssh \
      -i "$SSH_KEY_PATH" \
      -o BatchMode=yes \
      -o ConnectTimeout=3 \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -p "$SSH_HOST_PORT" \
      "${REMOTE_USER}@${HOST_LISTEN_ADDRESS}" \
      docker ps >/dev/null 2>&1; then
      ok "SSH-backed Docker endpoint confirmed reachable at ${HOST_LISTEN_ADDRESS}:${SSH_HOST_PORT}"
      return 0
    fi

    if cloud_init_output="$(incus exec "$VM_NAME" -- cloud-init status 2>/dev/null)"; then
      READINESS_FAILURE_REASON="cloud-init-incomplete"
      if [[ "$guest_agent_reachable_reported" -eq 0 ]]; then
        step "Guest agent became reachable for ${VM_NAME}; collecting cloud-init readiness"
        guest_agent_reachable_reported=1
      fi

      if cloud_init_status_is_failure "$cloud_init_output"; then
        READINESS_FAILURE_REASON="cloud-init-failed"
        fail "Cloud-init reported a terminal failure inside ${VM_NAME}; aborting readiness wait before SSH proxy timeout"
        fail_vm_readiness
      elif cloud_init_status_is_done "$cloud_init_output"; then
        READINESS_FAILURE_REASON="ssh-proxy-unreachable"
        if [[ "$ssh_proxy_wait_reported" -eq 0 ]]; then
          step "Guest booted and cloud-init completed, but SSH proxy unreachable at ${HOST_LISTEN_ADDRESS}:${SSH_HOST_PORT}; waiting for endpoint reachability"
          ssh_proxy_wait_reported=1
        fi
      elif [[ "$cloud_init_wait_reported" -eq 0 ]]; then
        step "Guest agent reachable but cloud-init has not completed yet; waiting for SSH endpoint ${HOST_LISTEN_ADDRESS}:${SSH_HOST_PORT}"
        cloud_init_wait_reported=1
      fi
    elif incus exec "$VM_NAME" -- systemctl is-active --quiet ssh >/dev/null 2>&1; then
      READINESS_FAILURE_REASON="cloud-init-incomplete"
      if [[ "$guest_agent_reachable_reported" -eq 0 ]]; then
        step "Guest agent became reachable for ${VM_NAME}; collecting cloud-init readiness"
        guest_agent_reachable_reported=1
      fi
      if [[ "$cloud_init_wait_reported" -eq 0 ]]; then
        step "Guest booted but cloud-init completion has not been observed yet; waiting for SSH endpoint ${HOST_LISTEN_ADDRESS}:${SSH_HOST_PORT}"
        cloud_init_wait_reported=1
      fi
    elif [[ "$guest_agent_unavailable_reported" -eq 0 ]]; then
      READINESS_FAILURE_REASON="guest-agent-unreachable"
      warn "Guest agent unavailable; still waiting for SSH endpoint ${HOST_LISTEN_ADDRESS}:${SSH_HOST_PORT}"
      guest_agent_unavailable_reported=1
    fi

    sleep 3
  done

  fail_vm_readiness
}

append_timeout_diagnostic_command() {
  local label="$1"
  shift
  {
    echo
    echo "### ${label}"
    echo "\$ $*"
    if "$@"; then
      :
    else
      local status=$?
      echo "[command exited with status ${status}]"
    fi
  } >>"$BOOTSTRAP_LOG_FILE" 2>&1
}

append_timeout_guest_exec_diagnostic() {
  local label="$1"
  shift

  {
    echo
    echo "### ${label}"
    echo "\$ incus exec ${VM_NAME} -- $*"
  } >>"$BOOTSTRAP_LOG_FILE"

  if incus exec "$VM_NAME" -- "$@" >>"$BOOTSTRAP_LOG_FILE" 2>&1; then
    return 0
  fi

  local status=$?
  echo "[command exited with status ${status}]" >>"$BOOTSTRAP_LOG_FILE"
  return "$status"
}

collect_readiness_diagnostics() {
  {
    echo
    echo "===== TIMEOUT DIAGNOSTICS BEGIN ====="
    echo "VM: ${VM_NAME}"
    echo "Failure reason: ${READINESS_FAILURE_REASON:-unknown}"
    echo "SSH proxy endpoint: ${HOST_LISTEN_ADDRESS}:${SSH_HOST_PORT}"
    echo "Observed VM IPv4: ${VM_IPV4:-unavailable}"
    echo "Configured VM static IPv4: ${VM_STATIC_IPV4:-unavailable}"
    echo "Bridge gateway IPv4: ${INCUS_NETWORK_BRIDGE_IPV4:-unavailable}"
  } >>"$BOOTSTRAP_LOG_FILE"

  append_timeout_diagnostic_command "HOST: incus info" incus info "$VM_NAME"
  append_timeout_diagnostic_command "HOST: incus config show" incus config show "$VM_NAME"
  append_timeout_diagnostic_command "HOST: incus config device show" incus config device show "$VM_NAME"
  append_timeout_diagnostic_command "HOST: incus list -f json" incus list "$VM_NAME" -f json

  if incus exec "$VM_NAME" -- true >/dev/null 2>&1; then
    if command -v timeout >/dev/null 2>&1; then
      append_timeout_diagnostic_command "GUEST: cloud-init status --wait || cloud-init status" \
        timeout 15s incus exec "$VM_NAME" -- sh -lc 'cloud-init status --wait || cloud-init status'
    else
      append_timeout_guest_exec_diagnostic "GUEST: cloud-init status" cloud-init status
    fi
    append_timeout_guest_exec_diagnostic "GUEST: cloud-init status --long" cloud-init status --long
    append_timeout_guest_exec_diagnostic "GUEST: ip -4 addr" ip -4 addr
    append_timeout_guest_exec_diagnostic "GUEST: ip route" ip route
    append_timeout_guest_exec_diagnostic "GUEST: cat /etc/resolv.conf" cat /etc/resolv.conf
    append_timeout_guest_exec_diagnostic "GUEST: journalctl -u cloud-init --no-pager" journalctl -u cloud-init --no-pager
    append_timeout_guest_exec_diagnostic "GUEST: systemctl status ssh --no-pager" systemctl status ssh --no-pager
    append_timeout_guest_exec_diagnostic "GUEST: systemctl status docker --no-pager" systemctl status docker --no-pager
  else
    {
      echo
      echo "### GUEST: diagnostics unavailable"
      echo "incus exec ${VM_NAME} -- true failed; guest agent may still be unavailable."
    } >>"$BOOTSTRAP_LOG_FILE"
  fi

  {
    echo
    echo "### HOST: incus console --show-log"
    echo "\$ incus console --show-log ${VM_NAME}"
  } >>"$BOOTSTRAP_LOG_FILE"
  if incus console --show-log "$VM_NAME" >>"$BOOTSTRAP_LOG_FILE" 2>&1; then
    :
  else
    local status=$?
    {
      echo "[command exited with status ${status}; console log output may not be supported by this Incus version]"
    } >>"$BOOTSTRAP_LOG_FILE"
  fi

  echo "===== TIMEOUT DIAGNOSTICS END =====" >>"$BOOTSTRAP_LOG_FILE"
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

  python3 - "$template_path" "$rendered_path" "$VM_NAME" "$REMOTE_USER" "$SSH_KEY_PATH.pub" "$HOST_LISTEN_ADDRESS" "$VM_STATIC_IPV4" <<'PY'
import pathlib
import sys

template_path = pathlib.Path(sys.argv[1])
rendered_path = pathlib.Path(sys.argv[2])
vm_name = sys.argv[3]
remote_user = sys.argv[4]
ssh_pubkey_path = pathlib.Path(sys.argv[5])
host_listen_address = sys.argv[6]
vm_static_ipv4 = sys.argv[7]

text = template_path.read_text()
ssh_key = ssh_pubkey_path.read_text().strip()
docker_daemon_json = """{
  "features": {
    "buildkit": true
  },
  "log-driver": "journald",
  "dns": [
    "%s"
  ]
}""" % vm_static_ipv4
rendered = (text
    .replace("__VM_NAME__", vm_name)
    .replace("__REMOTE_USER__", remote_user)
    .replace("__SSH_PUBLIC_KEY__", ssh_key)
    .replace("__HOST_LISTEN_ADDRESS__", host_listen_address)
    .replace("__VM_STATIC_IPV4__", vm_static_ipv4)
    .replace("__DOCKER_DAEMON_JSON__", "\n".join(f"      {line}" for line in docker_daemon_json.splitlines())))
rendered_path.write_text(rendered)
PY

  echo "$rendered_path"
}

render_network_config() {
  local interface_mac="$1"
  local rendered_path
  rendered_path="$(mktemp /tmp/${VM_NAME}-network-config.XXXXXX.yaml)"

  python3 - "$rendered_path" "$VM_STATIC_IPV4" "$INCUS_NETWORK_IPV4_CIDR" "$INCUS_NETWORK_BRIDGE_IPV4" "$INCUS_NETWORK_DNS_NAMESERVERS" "$interface_mac" <<'PY'
import ipaddress
import pathlib
import re
import sys

rendered_path = pathlib.Path(sys.argv[1])
vm_static_ipv4 = sys.argv[2]
network_cidr = sys.argv[3]
default_gateway = sys.argv[4]
raw_nameservers = sys.argv[5]
interface_mac = sys.argv[6].lower()

interface = ipaddress.ip_interface(network_cidr)
prefixlen = interface.network.prefixlen
nameservers = [
    entry.strip()
    for entry in re.split(r"[\s,]+", raw_nameservers)
    if entry.strip() and entry.strip().lower() != "none"
]
if not nameservers:
    nameservers = [default_gateway]

lines = [
    "version: 2",
    "ethernets:",
    "  eth0:",
    "    match:",
    f"      macaddress: {interface_mac}",
    "    set-name: eth0",
    "    dhcp4: false",
    "    addresses:",
    f"      - {vm_static_ipv4}/{prefixlen}",
    "    routes:",
    "      - to: 0.0.0.0/0",
    f"        via: {default_gateway}",
    "    nameservers:",
    "      addresses:",
]
lines.extend(f"        - {address}" for address in nameservers)
rendered_path.write_text("\n".join(lines) + "\n")
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

reconcile_guest_hostname_overrides() {
  local temp_dir hosts_file dnsmasq_file docker_daemon_file hosts_script host_entry nameserver

  if [[ ${#RESOLVE_HOSTS[@]} -eq 0 ]]; then
    return 0
  fi

  temp_dir="$(mktemp -d /tmp/${VM_NAME}-host-overrides.XXXXXX)"
  hosts_file="${temp_dir}/ai-homebase-hosts"
  dnsmasq_file="${temp_dir}/ai-homebase-hosts.conf"
  docker_daemon_file="${temp_dir}/daemon.json"
  hosts_script="${temp_dir}/configure-hosts.sh"
  trap 'rm -rf "${temp_dir:-}" "${CLOUD_INIT_FILE:-}" "${NETWORK_CONFIG_FILE:-}"' EXIT

  : >"$hosts_file"
  for host_entry in "${RESOLVE_HOSTS[@]}"; do
    printf '%s %s\n' "$HOST_LISTEN_ADDRESS" "$host_entry" >>"$hosts_file"
  done

  cat >"$dnsmasq_file" <<EOF
bind-interfaces
listen-address=127.0.0.1,${VM_STATIC_IPV4}
cache-size=1000
EOF
  for host_entry in "${RESOLVE_HOSTS[@]}"; do
    printf 'address=/%s/%s\n' "$host_entry" "$HOST_LISTEN_ADDRESS" >>"$dnsmasq_file"
  done
  for nameserver in ${INCUS_NETWORK_DNS_NAMESERVERS//,/ }; do
    [[ -n "$nameserver" && "$nameserver" != "none" ]] || continue
    printf 'server=%s\n' "$nameserver" >>"$dnsmasq_file"
  done
  if ! grep -q '^server=' "$dnsmasq_file"; then
    printf 'server=%s\n' "$INCUS_NETWORK_BRIDGE_IPV4" >>"$dnsmasq_file"
  fi

  cat >"$docker_daemon_file" <<EOF
{
  "features": {
    "buildkit": true
  },
  "log-driver": "journald",
  "dns": [
    "${VM_STATIC_IPV4}"
  ]
}
EOF

  cat >"$hosts_script" <<'EOF'
#!/bin/sh
set -eu
touch /etc/hosts
while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  if grep -Fqx "$entry" /etc/hosts; then
    continue
  fi
  printf '%s\n' "$entry" >> /etc/hosts
done < /etc/ai-homebase-hosts
EOF

  step "Reconciling guest hostname overrides for ${VM_NAME}"
  run_checked incus exec "$VM_NAME" -- sh -ceu '
    export DEBIAN_FRONTEND=noninteractive
    if ! dpkg-query -W -f="${Status}" dnsmasq 2>/dev/null | grep -q "install ok installed"; then
      apt-get update
      apt-get install -y dnsmasq
    fi
  '
  run_checked incus file push "$hosts_file" "${VM_NAME}/etc/ai-homebase-hosts"
  run_checked incus file push "$dnsmasq_file" "${VM_NAME}/etc/dnsmasq.d/ai-homebase-hosts.conf"
  run_checked incus file push "$docker_daemon_file" "${VM_NAME}/etc/docker/daemon.json"
  run_checked incus file push "$hosts_script" "${VM_NAME}/usr/local/bin/ai-homebase-configure-hosts.sh"
  run_checked incus exec "$VM_NAME" -- chmod 0755 /usr/local/bin/ai-homebase-configure-hosts.sh
  run_checked incus exec "$VM_NAME" -- /usr/local/bin/ai-homebase-configure-hosts.sh
  run_checked incus exec "$VM_NAME" -- systemctl enable dnsmasq
  run_checked incus exec "$VM_NAME" -- systemctl restart dnsmasq
  run_checked incus exec "$VM_NAME" -- systemctl restart docker.service
  ok "Guest hostname overrides reconciled for ${VM_NAME}"
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
  local guest_ipv4="${VM_IPV4:-${VM_STATIC_IPV4}}"

  cat >"$CONNECTION_INFO_PATH" <<EOF
HOST_ALIAS=${HOST_ALIAS}
HOST_LISTEN_ADDRESS=${HOST_LISTEN_ADDRESS}
SSH_HOST_PORT=${SSH_HOST_PORT}
REMOTE_USER=${REMOTE_USER}
VM_IPV4=${guest_ipv4}
VM_STATIC_IPV4=${VM_STATIC_IPV4}
DOCKER_HOST=ssh://${REMOTE_USER}@${HOST_LISTEN_ADDRESS}:${SSH_HOST_PORT}
EOF
}

ensure_ssh_key
autodetect_network_addresses
validate_network_dns_strategy
normalize_resolve_hosts
CLOUD_INIT_FILE="$(render_cloud_init)"
NETWORK_CONFIG_FILE=""
trap 'rm -f "${CLOUD_INIT_FILE:-}" "${NETWORK_CONFIG_FILE:-}"' EXIT

if instance_exists; then
  step "Reusing existing Incus VM ${VM_NAME}"
else
  step "Creating Incus VM ${VM_NAME} from ${INCUS_IMAGE}"
  run_checked incus init "$INCUS_IMAGE" "$VM_NAME" --vm --network "$INCUS_NETWORK" --device "root,size=${DISK_SIZE}"
  ok "Created Incus VM ${VM_NAME}"
fi

run_checked incus config set "$VM_NAME" limits.cpu "$CPU_LIMIT"
run_checked incus config set "$VM_NAME" limits.memory "$MEMORY_LIMIT"
VM_ETH0_HWADDR="$(get_vm_eth0_hwaddr)"
if [[ -z "$VM_ETH0_HWADDR" ]]; then
  fail "Unable to determine ${VM_NAME} NIC MAC from 'incus config show ${VM_NAME}' (expected volatile.eth0.hwaddr)"
  exit 1
fi
NETWORK_CONFIG_FILE="$(render_network_config "$VM_ETH0_HWADDR")"
if [[ "${BOOTSTRAP_VERBOSE:-0}" == "1" ]]; then
  incus config set "$VM_NAME" user.user-data="$(cat "$CLOUD_INIT_FILE")"
  incus config set "$VM_NAME" user.network-config="$(cat "$NETWORK_CONFIG_FILE")"
else
  incus config set "$VM_NAME" user.user-data="$(cat "$CLOUD_INIT_FILE")" >>"$BOOTSTRAP_LOG_FILE" 2>&1
  incus config set "$VM_NAME" user.network-config="$(cat "$NETWORK_CONFIG_FILE")" >>"$BOOTSTRAP_LOG_FILE" 2>&1
fi
ensure_root_disk_size
ensure_vm_static_ip
ensure_proxy_device

if ! instance_running; then
  step "Starting Incus VM ${VM_NAME}"
  run_checked incus start "$VM_NAME"
else
  step "Incus VM ${VM_NAME} is already running"
fi

step "Waiting for Incus VM SSH readiness (timeout: ${SSH_READY_TIMEOUT_SECONDS}s)"
wait_for_vm_readiness
if [[ -n "${VM_IPV4:-}" ]]; then
  ok "Incus VM ${VM_NAME} is ready with runtime IPv4 ${VM_IPV4}"
else
  ok "Incus VM ${VM_NAME} is ready; using configured static IPv4 ${VM_STATIC_IPV4}"
fi

write_connection_info
reconcile_guest_hostname_overrides

guest_ipv4_display="${VM_IPV4:-${VM_STATIC_IPV4}}"

echo "Incus VM ready"
echo "  Name: ${VM_NAME}"
echo "  Guest IP: ${guest_ipv4_display}"
echo "  VM static IPv4: ${VM_STATIC_IPV4}"
echo "  SSH proxy endpoint (host alias): ssh://${REMOTE_USER}@${HOST_ALIAS}:${SSH_HOST_PORT}"
echo "  SSH proxy listen address: ${HOST_LISTEN_ADDRESS}:${SSH_HOST_PORT}"
echo "  SSH key: ${SSH_KEY_PATH}"
echo "  Docker host hint: DOCKER_HOST=ssh://${REMOTE_USER}@${HOST_LISTEN_ADDRESS}:${SSH_HOST_PORT}"
echo "  Connection info: ${CONNECTION_INFO_PATH}"
echo "  Bootstrap log: ${BOOTSTRAP_LOG_FILE}"
