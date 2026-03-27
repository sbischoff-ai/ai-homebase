#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_PATH="${REPO_ROOT}/scripts/k3d-up.sh"

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
  local docker_mount_mode="$2"
  local expected_status="$3"

  local sandbox_dir repo_dir fake_bin output_file
  sandbox_dir="$(mktemp -d)"
  trap 'rm -rf "${sandbox_dir}"' RETURN
  repo_dir="${sandbox_dir}/repo"
  fake_bin="${sandbox_dir}/bin"
  output_file="${sandbox_dir}/output.log"
  mkdir -p "${repo_dir}/scripts/lib" "${fake_bin}"

  cp "${SCRIPT_PATH}" "${repo_dir}/scripts/k3d-up.sh"
  cp "${REPO_ROOT}/scripts/lib/logging.sh" "${repo_dir}/scripts/lib/logging.sh"
  chmod +x "${repo_dir}/scripts/k3d-up.sh"

  cat >"${fake_bin}/k3d" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "$1 $2" in
  "kubeconfig get")
    printf 'apiVersion: v1\nclusters: []\n'
    ;;
  *)
    printf 'unexpected k3d invocation: %s\n' "$*" >&2
    exit 1
    ;;
esac
SH
  chmod +x "${fake_bin}/k3d"

  cat >"${fake_bin}/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == "inspect" ]]; then
  if [[ "${FAKE_DOCKER_MOUNT_MODE:-present}" == "present" ]]; then
    printf '%s|/var/lib/ai-homebase/openclaw-state\n' "${FAKE_SHARED_STATE_SOURCE:?}"
  fi
  exit 0
fi
printf 'unexpected docker invocation: %s\n' "$*" >&2
exit 1
SH
  chmod +x "${fake_bin}/docker"

  cat >"${fake_bin}/kubectl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == "--kubeconfig" ]]; then
  shift 2
fi
case "$1" in
  config)
    if [[ "${2:-}" == "use-context" ]]; then
      exit 0
    fi
    if [[ "${2:-}" == "current-context" ]]; then
      printf 'k3d-test-cluster'
      exit 0
    fi
    ;;
  wait)
    exit 0
    ;;
  get)
    if [[ "${2:-}" == "apiservice" ]]; then
      exit 1
    fi
    ;;
  *)
    ;;
esac
printf 'unexpected kubectl invocation: %s\n' "$*" >&2
exit 1
SH
  chmod +x "${fake_bin}/kubectl"

  cat >"${fake_bin}/helm" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  repo|upgrade)
    exit 0
    ;;
  *)
    exit 1
    ;;
esac
SH
  chmod +x "${fake_bin}/kubectl"
  chmod +x "${fake_bin}/helm"

  local status=0
  (
    cd "${repo_dir}"
    export PATH="${fake_bin}:$PATH"
    export FAKE_DOCKER_MOUNT_MODE="${docker_mount_mode}"
    export FAKE_SHARED_STATE_SOURCE="${sandbox_dir}/shared-state"
    ./scripts/k3d-up.sh --cluster-name test-cluster --kubeconfig "${sandbox_dir}/kubeconfig.yaml" --shared-openclaw-state-source "${sandbox_dir}/shared-state"
  ) >"${output_file}" 2>&1 || status=$?

  local output
  output="$(cat "${output_file}")"

  if [[ "${expected_status}" == "success" ]]; then
    if [[ ${status} -ne 0 ]]; then
      printf 'expected success but got status %s\n' "${status}" >&2
      printf 'actual output:\n%s\n' "${output}" >&2
      exit 1
    fi
    assert_contains "${output}" "Existing cluster has the shared OpenClaw state mount"
  else
    if [[ ${status} -eq 0 ]]; then
      printf 'expected failure but got success\n' >&2
      printf 'actual output:\n%s\n' "${output}" >&2
      exit 1
    fi
    assert_contains "${output}" "missing the shared OpenClaw state mount"
  fi

  trap - RETURN
  rm -rf "${sandbox_dir}"
}

run_case shared-mount-present "present" "success"
run_case shared-mount-missing "missing" "failure"

echo "k3d up tests passed"
