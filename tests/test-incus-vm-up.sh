#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_PATH="${REPO_ROOT}/scripts/incus-vm-up.sh"

run_case() {
  local case_name="$1"
  local local_root="$2"
  local sandbox_dir
  sandbox_dir="$(mktemp -d)"

  local fake_bin="${sandbox_dir}/bin"
  local state_dir="${sandbox_dir}/state"
  local log_file="${sandbox_dir}/incus.log"
  local bootstrap_log="${sandbox_dir}/bootstrap.log"
  local key_path="${sandbox_dir}/keys/test-id_ed25519"
  mkdir -p "${fake_bin}" "${state_dir}"

  cat >"${fake_bin}/incus" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
log_file="${FAKE_INCUS_LOG:?}"
state_dir="${FAKE_INCUS_STATE_DIR:?}"
local_root="${FAKE_INCUS_LOCAL_ROOT:-0}"
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
      printf '[]\n'
      exit 0
    fi
    ;;
  start)
    echo RUNNING >"${state_dir}/status"
    exit 0
    ;;
  config)
    subcommand="$1"
    shift
    case "${subcommand}" in
      show)
        if [[ "${local_root}" == "1" ]]; then
          cat <<'YAML'
architecture: x86_64
config: {}
devices:
  root:
    path: /
    pool: default
    type: disk
profiles:
- default
YAML
        else
          cat <<'YAML'
architecture: x86_64
config: {}
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
          show|set|add|override)
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
if [[ "$1" == "-c" ]]; then
  printf '192.0.2.10\n'
  exit 0
fi
if [[ "$1" == "-" ]]; then
  template_path="$2"
  rendered_path="$3"
  cp "${template_path}" "${rendered_path}"
  exit 0
fi
printf 'unexpected python3 invocation\n' >&2
exit 1
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

  PATH="${fake_bin}:$PATH" \
  FAKE_INCUS_LOG="${log_file}" \
  FAKE_INCUS_STATE_DIR="${state_dir}" \
  FAKE_INCUS_LOCAL_ROOT="${local_root}" \
  BOOTSTRAP_LOG_FILE="${bootstrap_log}" \
  "${SCRIPT_PATH}" \
    --vm-name test-vm \
    --ssh-key-path "${key_path}" \
    --state-dir "${sandbox_dir}/statefiles" \
    >/dev/null

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

  rm -rf "${sandbox_dir}"
}

run_case inherited-root 0
run_case local-root 1

echo "incus-vm-up tests passed"
