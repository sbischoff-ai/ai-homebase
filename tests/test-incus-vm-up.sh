#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_PATH="${REPO_ROOT}/scripts/incus-vm-up.sh"

run_case() {
  local case_name="$1"
  local local_root="$2"
  local local_eth0="$3"
  local proxy_exists="$4"
  local guest_ip_available="$5"
  local ssh_success_after="${6:-1}"
  local ssh_ready_timeout_seconds="${7:-}"
  local dns_nameservers="10.10.10.53,1.1.1.1"
  local host_listen_address=""
  local dns_mode="managed"
  local network_managed="true"
  local ipv4_nat="true"
  if [[ $# -ge 8 ]]; then
    dns_nameservers="$8"
  fi
  if [[ $# -ge 9 ]]; then
    host_listen_address="$9"
  fi
  if [[ $# -ge 10 ]]; then
    dns_mode="$10"
  fi
  if [[ $# -ge 11 ]]; then
    network_managed="$11"
  fi
  if [[ $# -ge 12 ]]; then
    ipv4_nat="$12"
  fi
  local sandbox_dir
  sandbox_dir="$(mktemp -d)"

  local fake_bin="${sandbox_dir}/bin"
  local state_dir="${sandbox_dir}/state"
  local log_file="${sandbox_dir}/incus.log"
  local ssh_log_file="${sandbox_dir}/ssh.log"
  local sleep_log_file="${sandbox_dir}/sleep.log"
  local bootstrap_log="${sandbox_dir}/bootstrap.log"
  local output_log="${sandbox_dir}/output.log"
  local key_path="${sandbox_dir}/keys/test-id_ed25519"
  local real_python3
  real_python3="$(python3 -c 'import sys; print(sys.executable)')"
  mkdir -p "${fake_bin}" "${state_dir}"

  cat >"${fake_bin}/incus" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
log_file="${FAKE_INCUS_LOG:?}"
state_dir="${FAKE_INCUS_STATE_DIR:?}"
local_root="${FAKE_INCUS_LOCAL_ROOT:-0}"
local_eth0="${FAKE_INCUS_LOCAL_ETH0:-0}"
proxy_exists="${FAKE_INCUS_PROXY_EXISTS:-0}"
guest_ip_available="${FAKE_INCUS_GUEST_IP_AVAILABLE:-1}"
dns_nameservers="${FAKE_INCUS_DNS_NAMESERVERS:-}"
dns_mode="${FAKE_INCUS_DNS_MODE:-managed}"
network_managed="${FAKE_INCUS_NETWORK_MANAGED:-true}"
ipv4_nat="${FAKE_INCUS_IPV4_NAT:-true}"
printf '%s\n' "$*" >>"${log_file}"
command="$1"
shift
case "${command}" in
  info)
    if [[ -f "${state_dir}/exists" ]]; then
      exit 0
    fi
    exit 1
    ;;
  init)
    touch "${state_dir}/exists"
    echo STOPPED >"${state_dir}/status"
    exit 0
    ;;
  list)
    if [[ "$2" == "-f" && "$3" == "csv" ]]; then
      cat "${state_dir}/status"
      exit 0
    fi
    if [[ "$2" == "-f" && "$3" == "json" ]]; then
      if [[ "${guest_ip_available}" == "1" ]]; then
        cat <<'JSON'
[{"state":{"network":{"eth0":{"addresses":[{"family":"inet","scope":"global","address":"192.0.2.10"}]}}}}]
JSON
      else
        printf '[]\n'
      fi
      exit 0
    fi
    ;;
  network)
    if [[ "$1" == "get" && "$3" == "ipv4.address" ]]; then
      printf '10.10.10.1/24\n'
      exit 0
    fi
    if [[ "$1" == "get" && "$3" == "ipv4.nat" ]]; then
      printf '%s\n' "${ipv4_nat}"
      exit 0
    fi
    if [[ "$1" == "get" && "$3" == "dns.nameservers" ]]; then
      printf '%s\n' "${dns_nameservers}"
      exit 0
    fi
    if [[ "$1" == "get" && "$3" == "dns.mode" ]]; then
      printf '%s\n' "${dns_mode}"
      exit 0
    fi
    if [[ "$1" == "show" || "$2" == "show" ]]; then
      cat <<YAML
managed: ${network_managed}
type: bridge
config:
  dns.mode: ${dns_mode}
  dns.nameservers: ${dns_nameservers}
  ipv4.address: 10.10.10.1/24
  ipv4.nat: "${ipv4_nat}"
YAML
      exit 0
    fi
    ;;
  start)
    echo RUNNING >"${state_dir}/status"
    exit 0
    ;;
  file)
    if [[ "$1" == "push" ]]; then
      exit 0
    fi
    ;;
  exec)
    if [[ "$1" == "test-vm" && "$2" == "--" && "$3" == "systemctl" && "$4" == "is-active" && "$5" == "--quiet" && "$6" == "ssh" ]]; then
      exit 0
    fi
    if [[ "$1" == "test-vm" && "$2" == "--" ]]; then
      shift 2
      if [[ "$*" == "sh -ceu "* ]]; then
        exit 0
      fi
      case "$*" in
        "chmod 0755 /usr/local/bin/ai-homebase-configure-hosts.sh"|\
        "/usr/local/bin/ai-homebase-configure-hosts.sh"|\
        "systemctl enable dnsmasq"|\
        "systemctl restart dnsmasq"|\
        "systemctl restart docker.service")
          exit 0
          ;;
      esac
    fi
    ;;
  config)
    subcommand="$1"
    shift
    case "${subcommand}" in
      show)
        if [[ "${local_root}" == "1" || "${local_eth0}" == "1" ]]; then
          cat <<YAML
architecture: x86_64
config:
  volatile.eth0.hwaddr: "00:16:3e:aa:bb:cc"
devices:
$(if [[ "${local_root}" == "1" ]]; then cat <<'INNER'
  root:
    path: /
    pool: default
    type: disk
INNER
fi)
$(if [[ "${local_eth0}" == "1" ]]; then cat <<'INNER'
  eth0:
    name: eth0
    network: incusbr0
    type: nic
INNER
fi)
profiles:
- default
YAML
        else
          cat <<'YAML'
architecture: x86_64
config:
  volatile.eth0.hwaddr: "00:16:3e:aa:bb:cc"
profiles:
- default
YAML
        fi
        exit 0
        ;;
      set)
        exit 0
        ;;
      device)
        device_cmd="$1"
        shift
        case "${device_cmd}" in
          show)
            if [[ "${proxy_exists}" == "1" ]]; then
              cat <<'YAML'
ssh-proxy:
  type: proxy
YAML
            fi
            exit 0
            ;;
          set|add|override)
            exit 0
            ;;
        esac
        ;;
    esac
    ;;
esac
printf 'unexpected incus invocation: %s\n' "$command $*" >&2
exit 1
SH
  chmod +x "${fake_bin}/incus"

  cat >"${fake_bin}/python3" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
exec "${REAL_PYTHON3:?}" "$@"
SH
  chmod +x "${fake_bin}/python3"

  cat >"${fake_bin}/ssh-keygen" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
key_path=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f)
      key_path="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
mkdir -p "$(dirname "${key_path}")"
printf 'PRIVATE\n' >"${key_path}"
printf 'PUBLIC\n' >"${key_path}.pub"
SH
  chmod +x "${fake_bin}/ssh-keygen"

  cat >"${fake_bin}/ssh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
log_file="${FAKE_SSH_LOG:?}"
state_dir="${FAKE_SSH_STATE_DIR:?}"
success_after="${FAKE_SSH_SUCCESS_AFTER:-1}"
counter_file="${state_dir}/ssh-attempts"
attempt=1
if [[ -f "${counter_file}" ]]; then
  attempt="$(( $(cat "${counter_file}") + 1 ))"
fi
printf '%s' "${attempt}" >"${counter_file}"
printf 'attempt=%s args=%s\n' "${attempt}" "$*" >>"${log_file}"
if (( attempt >= success_after )); then
  exit 0
fi
exit 255
SH
  chmod +x "${fake_bin}/ssh"

  cat >"${fake_bin}/sleep" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${FAKE_SLEEP_LOG:?}"
exit 0
SH
  chmod +x "${fake_bin}/sleep"

  local -a command=(
    "${SCRIPT_PATH}"
    --vm-name test-vm
    --vm-static-ipv4 10.10.10.45
    --ssh-key-path "${key_path}"
    --state-dir "${sandbox_dir}/statefiles"
  )

  if [[ -n "${host_listen_address}" ]]; then
    command+=(--host-listen-address "${host_listen_address}")
  fi

  PATH="${fake_bin}:$PATH" \
  FAKE_INCUS_LOG="${log_file}" \
  FAKE_INCUS_STATE_DIR="${state_dir}" \
  FAKE_INCUS_LOCAL_ROOT="${local_root}" \
  FAKE_INCUS_LOCAL_ETH0="${local_eth0}" \
  FAKE_INCUS_PROXY_EXISTS="${proxy_exists}" \
  FAKE_INCUS_GUEST_IP_AVAILABLE="${guest_ip_available}" \
  FAKE_INCUS_DNS_NAMESERVERS="${dns_nameservers}" \
  FAKE_INCUS_DNS_MODE="${dns_mode}" \
  FAKE_INCUS_NETWORK_MANAGED="${network_managed}" \
  FAKE_INCUS_IPV4_NAT="${ipv4_nat}" \
  FAKE_SSH_LOG="${ssh_log_file}" \
  FAKE_SSH_STATE_DIR="${state_dir}" \
  FAKE_SSH_SUCCESS_AFTER="${ssh_success_after}" \
  FAKE_SLEEP_LOG="${sleep_log_file}" \
  REAL_PYTHON3="${real_python3}" \
  BOOTSTRAP_LOG_FILE="${bootstrap_log}" \
  SSH_READY_TIMEOUT_SECONDS="${ssh_ready_timeout_seconds}" \
  "${command[@]}" \
    >"${output_log}" 2>&1

  local expected_host_listen_address="${host_listen_address:-10.10.10.1}"

  case "${case_name}" in
    inherited-root)
      grep -F 'init images:debian/12/cloud test-vm --vm --network incusbr0 --device root,size=12GiB' "${log_file}" >/dev/null
      grep -F 'config device override test-vm root size=12GiB' "${log_file}" >/dev/null
      if grep -F 'config device set test-vm root size 12GiB' "${log_file}" >/dev/null; then
        echo "expected inherited root case to avoid config device set" >&2
        return 1
      fi
      ;;
    local-root)
      grep -F 'config device set test-vm root size 12GiB' "${log_file}" >/dev/null
      if grep -F 'config device override test-vm root size=12GiB' "${log_file}" >/dev/null; then
        echo "expected local root case to avoid config device override" >&2
        return 1
      fi
      ;;
  esac

  grep -F -- '-i '"${key_path}" "${ssh_log_file}" >/dev/null
  grep -F -- '-o BatchMode=yes' "${ssh_log_file}" >/dev/null
  grep -F -- '-o ConnectTimeout=3' "${ssh_log_file}" >/dev/null
  grep -F -- '-o StrictHostKeyChecking=no' "${ssh_log_file}" >/dev/null
  grep -F -- '-o UserKnownHostsFile=/dev/null' "${ssh_log_file}" >/dev/null
  grep -F -- '-p 2222' "${ssh_log_file}" >/dev/null
  grep -F -- "docker-remote@${expected_host_listen_address} docker ps" "${ssh_log_file}" >/dev/null

  case "${proxy_exists}" in
    0)
      grep -F "config device add test-vm ssh-proxy proxy listen=tcp:${expected_host_listen_address}:2222 connect=tcp:0.0.0.0:22 nat=true" "${log_file}" >/dev/null
      ;;
    1)
      grep -F "config device set test-vm ssh-proxy listen tcp:${expected_host_listen_address}:2222" "${log_file}" >/dev/null
      grep -F 'config device set test-vm ssh-proxy connect tcp:0.0.0.0:22' "${log_file}" >/dev/null
      grep -F 'config device set test-vm ssh-proxy nat true' "${log_file}" >/dev/null
      ;;
  esac

  case "${local_eth0}" in
    0)
      grep -F 'config device override test-vm eth0 ipv4.address=10.10.10.45' "${log_file}" >/dev/null
      if grep -F 'config device set test-vm eth0 ipv4.address 10.10.10.45' "${log_file}" >/dev/null; then
        echo "expected inherited eth0 case to avoid config device set" >&2
        return 1
      fi
      ;;
    1)
      grep -F 'config device set test-vm eth0 ipv4.address 10.10.10.45' "${log_file}" >/dev/null
      if grep -F 'config device override test-vm eth0 ipv4.address=10.10.10.45' "${log_file}" >/dev/null; then
        echo "expected local eth0 case to avoid config device override" >&2
        return 1
      fi
      ;;
  esac

  grep -F "HOST_LISTEN_ADDRESS=${expected_host_listen_address}" "${sandbox_dir}/statefiles/test-vm.env" >/dev/null
  grep -F 'VM_STATIC_IPV4=10.10.10.45' "${sandbox_dir}/statefiles/test-vm.env" >/dev/null
  grep -F 'config set test-vm user.user-data=#cloud-config' "${log_file}" >/dev/null
  grep -F 'config set test-vm user.network-config=version: 2' "${log_file}" >/dev/null
  grep -F '    match:' "${log_file}" >/dev/null
  grep -F '      macaddress: 00:16:3e:aa:bb:cc' "${log_file}" >/dev/null
  grep -F '    set-name: eth0' "${log_file}" >/dev/null
  grep -F '      - 10.10.10.45/24' "${log_file}" >/dev/null
  grep -F '      - to: 0.0.0.0/0' "${log_file}" >/dev/null
  grep -F '        via: 10.10.10.1' "${log_file}" >/dev/null
  if grep -F '      - to: default' "${log_file}" >/dev/null; then
    echo "expected cloud-init-compatible default route instead of to: default" >&2
    return 1
  fi

  case "${dns_nameservers}" in
    "")
      grep -F '        - 10.10.10.1' "${log_file}" >/dev/null
      ;;
    *)
      grep -F '        - 10.10.10.53' "${log_file}" >/dev/null
      grep -F '        - 1.1.1.1' "${log_file}" >/dev/null
      ;;
  esac

  case "${guest_ip_available}" in
    0)
      grep -F 'VM_IPV4=10.10.10.45' "${sandbox_dir}/statefiles/test-vm.env" >/dev/null
      ;;
    1)
      grep -F 'VM_IPV4=192.0.2.10' "${sandbox_dir}/statefiles/test-vm.env" >/dev/null
      ;;
  esac

  case "${ssh_success_after}" in
    1)
      if [[ -s "${sleep_log_file}" ]]; then
        echo "expected immediate SSH readiness to avoid sleeping" >&2
        return 1
      fi
      if grep -F 'Guest booted but SSH proxy unreachable' "${output_log}" >/dev/null; then
        echo "expected immediate SSH readiness to avoid fallback boot message" >&2
        return 1
      fi
      ;;
    *)
      grep -F 'Guest booted but cloud-init completion has not been observed yet; waiting for SSH endpoint 10.10.10.1:2222' "${output_log}" >/dev/null
      grep -F 'SSH-backed Docker endpoint confirmed reachable at 10.10.10.1:2222' "${output_log}" >/dev/null
      grep -F 'attempt=1 ' "${ssh_log_file}" >/dev/null
      grep -F "attempt=${ssh_success_after} " "${ssh_log_file}" >/dev/null
      if [[ "$(wc -l < "${sleep_log_file}")" -ne $((ssh_success_after - 1)) ]]; then
        echo "expected one sleep per failed SSH attempt" >&2
        return 1
      fi
      ;;
  esac

  if [[ -n "${ssh_ready_timeout_seconds}" ]]; then
    grep -F "Waiting for Incus VM SSH readiness (timeout: ${ssh_ready_timeout_seconds}s)" "${output_log}" >/dev/null
  else
    grep -F 'Waiting for Incus VM SSH readiness (timeout: 1800s)' "${output_log}" >/dev/null
  fi

  case "${dns_nameservers}" in
    "")
      grep -F 'Resolved guest DNS strategy: bridge gateway fallback via 10.10.10.1' "${output_log}" >/dev/null
      grep -F 'has an empty dns.nameservers setting; falling back to bridge gateway 10.10.10.1 for guest DNS. Ensure this bridge provides DNS service to guests or cloud-init package installation may fail.' "${output_log}" >/dev/null
      ;;
    *)
      grep -F 'Resolved guest DNS strategy: explicit resolvers from incusbr0.dns.nameservers (10.10.10.53,1.1.1.1)' "${output_log}" >/dev/null
      ;;
  esac

  grep -F "Incus network incusbr0 details: ipv4.address=10.10.10.1/24, ipv4.nat=${ipv4_nat}, dns.nameservers=${dns_nameservers:-<empty>}, dns.mode=${dns_mode}, managed=${network_managed}, type=bridge" "${output_log}" >/dev/null

  rm -rf "${sandbox_dir}"
}

run_invalid_dns_fallback_case() {
  local sandbox_dir
  sandbox_dir="$(mktemp -d)"

  local fake_bin="${sandbox_dir}/bin"
  local log_file="${sandbox_dir}/output.log"
  local bootstrap_log="${sandbox_dir}/bootstrap.log"
  local incus_log="${sandbox_dir}/incus.log"
  local real_python3
  real_python3="$(python3 -c 'import sys; print(sys.executable)')"
  mkdir -p "${fake_bin}"

  cat >"${fake_bin}/incus" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${FAKE_INVALID_DNS_INCUS_LOG:?}"
command="$1"
shift
case "${command}" in
  info)
    exit 1
    ;;
  network)
    if [[ "$1" == "get" && "$3" == "ipv4.address" ]]; then
      printf '10.10.10.1/24\n'
      exit 0
    fi
    if [[ "$1" == "get" && "$3" == "ipv4.nat" ]]; then
      printf 'true\n'
      exit 0
    fi
    if [[ "$1" == "get" && "$3" == "dns.nameservers" ]]; then
      printf '\n'
      exit 0
    fi
    if [[ "$1" == "get" && "$3" == "dns.mode" ]]; then
      printf 'none\n'
      exit 0
    fi
    if [[ "$1" == "show" ]]; then
      cat <<'YAML'
managed: true
type: bridge
config:
  dns.mode: none
  ipv4.address: 10.10.10.1/24
  ipv4.nat: "true"
YAML
      exit 0
    fi
    ;;
esac
printf 'unexpected incus invocation: %s\n' "$command $*" >&2
exit 1
SH
  chmod +x "${fake_bin}/incus"

  cat >"${fake_bin}/python3" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
exec "${REAL_PYTHON3:?}" "$@"
SH
  chmod +x "${fake_bin}/python3"

  cat >"${fake_bin}/ssh-keygen" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
key_path=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f)
      key_path="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
mkdir -p "$(dirname "${key_path}")"
printf 'PRIVATE\n' >"${key_path}"
printf 'PUBLIC\n' >"${key_path}.pub"
SH
  chmod +x "${fake_bin}/ssh-keygen"

  cat >"${fake_bin}/ssh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
exit 255
SH
  chmod +x "${fake_bin}/ssh"

  set +e
  PATH="${fake_bin}:$PATH" \
  REAL_PYTHON3="${real_python3}" \
  FAKE_INVALID_DNS_INCUS_LOG="${incus_log}" \
  BOOTSTRAP_LOG_FILE="${bootstrap_log}" \
  "${SCRIPT_PATH}" \
    --vm-name test-vm \
    --vm-static-ipv4 10.10.10.45 \
    --ssh-key-path "${sandbox_dir}/keys/test-id_ed25519" \
    --state-dir "${sandbox_dir}/statefiles" \
    >"${log_file}" 2>&1
  local status=$?
  set -e

  if [[ ${status} -eq 0 ]]; then
    echo "expected invalid dns fallback case to fail" >&2
    return 1
  fi

  grep -F 'has an empty dns.nameservers setting; falling back to bridge gateway 10.10.10.1 for guest DNS. Ensure this bridge provides DNS service to guests or cloud-init package installation may fail.' "${log_file}" >/dev/null
  grep -F 'is incompatible with guest DNS fallback: dns.nameservers is empty and dns.mode=none, so guests cannot rely on bridge gateway 10.10.10.1 for DNS.' "${log_file}" >/dev/null
  grep -F 'INCUS_NETWORK_DNS_NAMESERVERS' "${log_file}" >/dev/null
  if grep -F 'start test-vm' "${incus_log}" >/dev/null; then
    echo "expected invalid dns fallback case to fail before incus start" >&2
    return 1
  fi

  rm -rf "${sandbox_dir}"
}

run_timeout_failure_case() {
  local case_name="$1"
  local guest_agent_available="$2"
  local cloud_init_state="$3"
  local sandbox_dir
  sandbox_dir="$(mktemp -d)"

  local fake_bin="${sandbox_dir}/bin"
  local log_file="${sandbox_dir}/timeout.log"
  local bootstrap_log="${sandbox_dir}/bootstrap.log"
  local sleep_log="${sandbox_dir}/sleep.log"
  local ssh_log="${sandbox_dir}/ssh.log"
  mkdir -p "${fake_bin}"

cat >"${fake_bin}/incus" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
guest_agent_available="${FAKE_TIMEOUT_GUEST_AGENT_AVAILABLE:-0}"
cloud_init_state="${FAKE_TIMEOUT_CLOUD_INIT_STATE:-running}"
command="$1"
shift
case "${command}" in
  info)
    if [[ $# -eq 1 ]]; then
      cat <<'TXT'
Name: test-vm
Status: RUNNING
TXT
      exit 0
    fi
    exit 1
    ;;
  init|start) exit 0 ;;
  list)
    if [[ "$2" == "-f" && "$3" == "csv" ]]; then
      printf 'RUNNING\n'
      exit 0
    fi
    if [[ "$2" == "-f" && "$3" == "json" ]]; then
      printf '[]\n'
      exit 0
    fi
    ;;
  network)
    if [[ "$1" == "get" && "$3" == "ipv4.address" ]]; then
      printf '10.10.10.1/24\n'
      exit 0
    fi
    if [[ "$1" == "get" && "$3" == "dns.nameservers" ]]; then
      printf '\n'
      exit 0
    fi
    ;;
  config)
    subcommand="$1"
    shift
    case "${subcommand}" in
      set) exit 0 ;;
      show)
        cat <<'YAML'
architecture: x86_64
config:
  volatile.eth0.hwaddr: "00:16:3e:aa:bb:cc"
devices:
  ssh-proxy:
    connect: tcp:0.0.0.0:22
    listen: tcp:10.10.10.1:2222
    nat: "true"
    type: proxy
profiles:
- default
YAML
        exit 0
        ;;
      device)
        if [[ "$1" == "show" ]]; then
          cat <<'YAML'
ssh-proxy:
  connect: tcp:0.0.0.0:22
  listen: tcp:10.10.10.1:2222
  nat: "true"
  type: proxy
YAML
          exit 0
        fi
        exit 0
        ;;
    esac
    ;;
  exec)
    if [[ "${guest_agent_available}" != "1" ]]; then
      exit 1
    fi
    if [[ "$1" != "test-vm" || "$2" != "--" ]]; then
      exit 1
    fi
    shift 2
    case "$*" in
      "true")
        exit 0
        ;;
      "cloud-init status")
        case "${cloud_init_state}" in
          done) printf 'status: done\n' ;;
          error) printf 'status: error\n' ;;
          degraded) printf 'status: degraded done\n' ;;
          *) printf 'status: running\n' ;;
        esac
        exit 0
        ;;
      "sh -lc cloud-init status --wait || cloud-init status")
        if [[ "${cloud_init_state}" == "done" ]]; then
          printf 'status: done\n'
          exit 0
        fi
        if [[ "${cloud_init_state}" == "error" ]]; then
          printf 'status: error\n' >&2
        elif [[ "${cloud_init_state}" == "degraded" ]]; then
          printf 'status: degraded done\n' >&2
        else
          printf 'status: running\n' >&2
        fi
        exit 1
        ;;
      "cloud-init status --long")
        printf 'status: %s\n' "${cloud_init_state}"
        exit 0
        ;;
      "systemctl is-active --quiet ssh")
        exit 0
        ;;
      "ip -4 addr")
        printf '2: eth0    inet 10.10.10.45/24\n'
        exit 0
        ;;
      "ip route")
        printf 'default via 10.10.10.1 dev eth0\n10.10.10.0/24 dev eth0 proto kernel scope link src 10.10.10.45\n'
        exit 0
        ;;
      "cat /etc/resolv.conf")
        printf 'nameserver 10.10.10.53\nnameserver 1.1.1.1\n'
        exit 0
        ;;
      "resolvectl status")
        printf 'DNS Servers: 10.10.10.53 1.1.1.1\n'
        exit 0
        ;;
      "journalctl -u cloud-final --no-pager")
        printf 'cloud-final journal line\n'
        exit 0
        ;;
      "tail -n 200 /var/log/cloud-init-output.log")
        printf 'cloud-init output line\n'
        exit 0
        ;;
      "tail -n 120 /var/log/apt/term.log")
        printf 'apt term log line\n'
        exit 0
        ;;
      "sh -lc ps -eo pid,ppid,stat,etime,comm,args | grep -E \"(apt|apt-get|dpkg|cloud-init|cloud-final)\" | grep -v grep")
        printf '123 1 S 00:01 cloud-init cloud-init modules --mode=final\n'
        exit 0
        ;;
      "systemctl status ssh --no-pager")
        printf 'ssh.service active\n'
        exit 0
        ;;
      "systemctl status docker --no-pager")
        printf 'docker.service active\n'
        exit 0
        ;;
      "journalctl -u cloud-init --no-pager")
        printf 'cloud-init journal line\n'
        exit 0
        ;;
    esac
    ;;
  console)
    if [[ "$1" == "--show-log" && "$2" == "test-vm" ]]; then
      printf 'console log line\n'
      exit 0
    fi
    ;;
esac
printf 'unexpected incus invocation: %s\n' "$command $*" >&2
exit 1
SH
  chmod +x "${fake_bin}/incus"

  cat >"${fake_bin}/python3" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
exec "${REAL_PYTHON3:?}" "$@"
SH
  chmod +x "${fake_bin}/python3"

  cat >"${fake_bin}/ssh-keygen" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
key_path=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f)
      key_path="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
mkdir -p "$(dirname "${key_path}")"
printf 'PRIVATE\n' >"${key_path}"
printf 'PUBLIC\n' >"${key_path}.pub"
SH
  chmod +x "${fake_bin}/ssh-keygen"

  cat >"${fake_bin}/ssh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'args=%s\n' "$*" >>"${FAKE_TIMEOUT_SSH_LOG:?}"
exit 255
SH
  chmod +x "${fake_bin}/ssh"

  cat >"${fake_bin}/sleep" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${FAKE_SLEEP_LOG:?}"
exit 0
SH
  chmod +x "${fake_bin}/sleep"

  local real_python3
  real_python3="$(python3 -c 'import sys; print(sys.executable)')"

  set +e
  PATH="${fake_bin}:$PATH" \
  REAL_PYTHON3="${real_python3}" \
  FAKE_TIMEOUT_GUEST_AGENT_AVAILABLE="${guest_agent_available}" \
  FAKE_TIMEOUT_CLOUD_INIT_STATE="${cloud_init_state}" \
  FAKE_TIMEOUT_SSH_LOG="${ssh_log}" \
  FAKE_SLEEP_LOG="${sleep_log}" \
  BOOTSTRAP_LOG_FILE="${bootstrap_log}" \
  "${SCRIPT_PATH}" \
    --vm-name test-vm \
    --vm-static-ipv4 10.10.10.45 \
    --ssh-key-path "${sandbox_dir}/keys/test-id_ed25519" \
    --state-dir "${sandbox_dir}/statefiles" \
    --ssh-ready-timeout-seconds 1 \
    >"${log_file}" 2>&1
  local status=$?
  set -e

  if [[ ${status} -eq 0 ]]; then
    echo "expected zero-second timeout case to fail" >&2
    return 1
  fi

  grep -F 'Waiting for Incus VM SSH readiness (timeout: 1s)' "${log_file}" >/dev/null
  grep -F '===== TIMEOUT DIAGNOSTICS BEGIN =====' "${bootstrap_log}" >/dev/null
  grep -F '### HOST: incus info' "${bootstrap_log}" >/dev/null
  grep -F '### HOST: incus config show' "${bootstrap_log}" >/dev/null
  grep -F '### HOST: incus config device show' "${bootstrap_log}" >/dev/null
  grep -F '### HOST: incus list -f json' "${bootstrap_log}" >/dev/null
  grep -F '### HOST: incus console --show-log' "${bootstrap_log}" >/dev/null

  case "${case_name}" in
    guest-agent-unreachable)
      grep -F 'Failure reason: guest-agent-unreachable' "${bootstrap_log}" >/dev/null
      grep -F '### GUEST: diagnostics unavailable' "${bootstrap_log}" >/dev/null
      grep -F 'Timed out waiting for test-vm: failed to reach the guest agent and failed to connect to the SSH proxy at 10.10.10.1:2222.' "${log_file}" >/dev/null
      ;;
    cloud-init-incomplete)
      grep -F 'Failure reason: cloud-init-incomplete' "${bootstrap_log}" >/dev/null
      grep -F '### GUEST: cloud-init status --wait || cloud-init status' "${bootstrap_log}" >/dev/null
      grep -F '### GUEST: cloud-init status --long' "${bootstrap_log}" >/dev/null
      grep -F '### GUEST: ip -4 addr' "${bootstrap_log}" >/dev/null
      grep -F '### GUEST: ip route' "${bootstrap_log}" >/dev/null
      grep -F '### GUEST: cat /etc/resolv.conf' "${bootstrap_log}" >/dev/null
      grep -F '### GUEST: resolvectl status' "${bootstrap_log}" >/dev/null
      grep -F '### GUEST: journalctl -u cloud-init --no-pager' "${bootstrap_log}" >/dev/null
      grep -F '### GUEST: journalctl -u cloud-final --no-pager' "${bootstrap_log}" >/dev/null
      grep -F '### GUEST: tail /var/log/cloud-init-output.log' "${bootstrap_log}" >/dev/null
      grep -F '### GUEST: tail /var/log/apt/term.log' "${bootstrap_log}" >/dev/null
      grep -F '### GUEST: ps package processes' "${bootstrap_log}" >/dev/null
      grep -F '### GUEST: systemctl status ssh --no-pager' "${bootstrap_log}" >/dev/null
      grep -F '### GUEST: systemctl status docker --no-pager' "${bootstrap_log}" >/dev/null
      grep -F 'Timed out waiting for test-vm: guest agent became reachable, but failed to observe cloud-init completion before the SSH proxy at 10.10.10.1:2222 became reachable.' "${log_file}" >/dev/null
      ;;
    ssh-proxy-unreachable)
      grep -F 'Failure reason: ssh-proxy-unreachable' "${bootstrap_log}" >/dev/null
      grep -F '### GUEST: cloud-init status --wait || cloud-init status' "${bootstrap_log}" >/dev/null
      grep -F 'Timed out waiting for test-vm: cloud-init completed but failed to connect to the SSH proxy at 10.10.10.1:2222.' "${log_file}" >/dev/null
      ;;
    cloud-init-failed)
      grep -F 'Failure reason: cloud-init-failed' "${bootstrap_log}" >/dev/null
      grep -F '### GUEST: cloud-init status --wait || cloud-init status' "${bootstrap_log}" >/dev/null
      grep -F '### GUEST: cloud-init status --long' "${bootstrap_log}" >/dev/null
      grep -F '### GUEST: journalctl -u cloud-init --no-pager' "${bootstrap_log}" >/dev/null
      grep -F '### GUEST: journalctl -u cloud-final --no-pager' "${bootstrap_log}" >/dev/null
      grep -F '### GUEST: tail /var/log/cloud-init-output.log' "${bootstrap_log}" >/dev/null
      grep -F '### HOST: incus console --show-log' "${bootstrap_log}" >/dev/null
      grep -F 'Cloud-init reported a terminal failure inside test-vm; aborting readiness wait before SSH proxy timeout' "${log_file}" >/dev/null
      grep -F 'Failed waiting for test-vm: cloud-init failed inside the guest before the SSH proxy at 10.10.10.1:2222 became reachable.' "${log_file}" >/dev/null
      if [[ -s "${sleep_log}" ]]; then
        echo "expected cloud-init failure case to exit before sleeping" >&2
        return 1
      fi
      if [[ "$(wc -l < "${ssh_log}")" -ne 1 ]]; then
        echo "expected cloud-init failure case to stop after the first SSH probe" >&2
        return 1
      fi
      ;;
  esac

  rm -rf "${sandbox_dir}"
}

run_case inherited-root 0 0 0 1 3
run_case local-root 1 1 1 0 1 42
run_case dns-fallback 0 0 0 1 1 "" ""
run_case host-listen-override 0 0 0 1 1 "" "10.10.10.53,1.1.1.1" "127.0.0.1"
run_invalid_dns_fallback_case
run_timeout_failure_case guest-agent-unreachable 0 running
run_timeout_failure_case cloud-init-incomplete 1 running
run_timeout_failure_case ssh-proxy-unreachable 1 done
run_timeout_failure_case cloud-init-failed 1 error

echo "incus-vm-up tests passed"
