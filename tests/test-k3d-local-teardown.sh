#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

assert_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "${haystack}" != *"${needle}"* ]]; then
    printf 'expected output to contain: %s\n' "${needle}" >&2
    printf 'actual output:\n%s\n' "${haystack}" >&2
    exit 1
  fi
}

run_case() {
  local case_name="$1"
  local keep_flag="$2"
  local expected_state="$3"

  local sandbox_dir repo_dir output_file command_log shared_state_source
  sandbox_dir="$(mktemp -d)"
  trap 'rm -rf "${sandbox_dir}"' RETURN
  repo_dir="${sandbox_dir}/repo"
  output_file="${sandbox_dir}/output.log"
  command_log="${sandbox_dir}/commands.log"
  shared_state_source="${sandbox_dir}/openclaw-state"

  mkdir -p "${repo_dir}/scripts" "${shared_state_source}"
  cp "${REPO_ROOT}/scripts/k3d-local-teardown.sh" "${repo_dir}/scripts/k3d-local-teardown.sh"
  chmod +x "${repo_dir}/scripts/k3d-local-teardown.sh"

  cat >"${repo_dir}/scripts/k3d-down.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'k3d-down %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
SH
  chmod +x "${repo_dir}/scripts/k3d-down.sh"

  cat >"${repo_dir}/scripts/incus-vm-down.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'incus-vm-down %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
SH
  chmod +x "${repo_dir}/scripts/incus-vm-down.sh"

  (
    cd "${repo_dir}"
    export FAKE_COMMAND_LOG="${command_log}"
    export HOME="${sandbox_dir}"

    cmd=(
      ./scripts/k3d-local-teardown.sh
      --cluster-name test-cluster
      --vm-name test-vm
      --shared-openclaw-state-source "${shared_state_source}"
    )
    if [[ -n "${keep_flag}" ]]; then
      cmd+=("${keep_flag}")
    fi
    "${cmd[@]}"
  ) >"${output_file}" 2>&1

  local output commands
  output="$(cat "${output_file}")"
  commands="$(cat "${command_log}")"

  assert_contains "${commands}" "k3d-down --cluster-name test-cluster"
  assert_contains "${commands}" "incus-vm-down --vm-name test-vm"

  case "${expected_state}" in
    removed)
      [[ ! -d "${shared_state_source}" ]] || {
        printf 'expected shared state to be removed for case %s\n' "${case_name}" >&2
        exit 1
      }
      assert_contains "${output}" "Removing shared OpenClaw state at ${shared_state_source}"
      assert_contains "${output}" "Removed shared OpenClaw state at ${shared_state_source}"
      ;;
    kept)
      [[ -d "${shared_state_source}" ]] || {
        printf 'expected shared state to be preserved for case %s\n' "${case_name}" >&2
        exit 1
      }
      assert_contains "${output}" "Preserving shared OpenClaw state at ${shared_state_source}"
      ;;
    *)
      printf 'unexpected expected_state %s\n' "${expected_state}" >&2
      exit 1
      ;;
  esac

  trap - RETURN
  rm -rf "${sandbox_dir}"
}

run_missing_case() {
  local sandbox_dir repo_dir output_file command_log shared_state_source
  sandbox_dir="$(mktemp -d)"
  trap 'rm -rf "${sandbox_dir}"' RETURN
  repo_dir="${sandbox_dir}/repo"
  output_file="${sandbox_dir}/output.log"
  command_log="${sandbox_dir}/commands.log"
  shared_state_source="${sandbox_dir}/missing-openclaw-state"

  mkdir -p "${repo_dir}/scripts"
  cp "${REPO_ROOT}/scripts/k3d-local-teardown.sh" "${repo_dir}/scripts/k3d-local-teardown.sh"
  chmod +x "${repo_dir}/scripts/k3d-local-teardown.sh"

  cat >"${repo_dir}/scripts/k3d-down.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'k3d-down %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
SH
  chmod +x "${repo_dir}/scripts/k3d-down.sh"

  cat >"${repo_dir}/scripts/incus-vm-down.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'incus-vm-down %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
SH
  chmod +x "${repo_dir}/scripts/incus-vm-down.sh"

  (
    cd "${repo_dir}"
    export FAKE_COMMAND_LOG="${command_log}"
    export HOME="${sandbox_dir}"

    ./scripts/k3d-local-teardown.sh \
      --cluster-name test-cluster \
      --vm-name test-vm \
      --shared-openclaw-state-source "${shared_state_source}"
  ) >"${output_file}" 2>&1

  local output
  output="$(cat "${output_file}")"
  assert_contains "${output}" "Shared OpenClaw state path ${shared_state_source} does not exist; nothing to clean up"

  trap - RETURN
  rm -rf "${sandbox_dir}"
}

run_case default-delete "" removed
run_case keep-flag --keep-openclaw-state kept
run_missing_case

echo "k3d local teardown tests passed"
