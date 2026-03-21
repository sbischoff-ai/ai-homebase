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
  local token_value="$2"
  local sandbox_dir
  sandbox_dir="$(mktemp -d)"
  trap 'rm -rf "${sandbox_dir}"' RETURN

  local repo_dir="${sandbox_dir}/repo"
  mkdir -p "${repo_dir}/scripts/lib"
  cp "${REPO_ROOT}/scripts/k3d-local-bootstrap.sh" "${repo_dir}/scripts/k3d-local-bootstrap.sh"
  cp "${REPO_ROOT}/scripts/lib/logging.sh" "${repo_dir}/scripts/lib/logging.sh"
  chmod +x "${repo_dir}/scripts/k3d-local-bootstrap.sh"

  local command_log="${sandbox_dir}/commands.log"
  local kubeconfig_path="${sandbox_dir}/kubeconfig.yaml"

  for script_name in k3d-up.sh incus-vm-up.sh k3d-bootstrap-secrets.sh test-local-k3d.sh; do
    cat >"${repo_dir}/scripts/${script_name}" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s %s\n' "$(basename "$0")" "$*" >>"${FAKE_COMMAND_LOG:?}"
exit 0
SH
    chmod +x "${repo_dir}/scripts/${script_name}"
  done

  local output_file="${sandbox_dir}/output.log"
  (
    cd "${repo_dir}"
    export OPENAI_API_KEY="test-openai-key"
    export FAKE_COMMAND_LOG="${command_log}"
    if [[ -n "${token_value}" ]]; then
      export OPENCLAW_GATEWAY_TOKEN="${token_value}"
    fi

    ./scripts/k3d-local-bootstrap.sh \
      --cluster-name test-cluster \
      --namespace test-namespace \
      --release-name test-release \
      --kubeconfig "${kubeconfig_path}"
  ) >"${output_file}" 2>&1

  local output
  output="$(cat "${output_file}")"

  assert_contains "${output}" "Local bootstrap complete."
  assert_contains "${output}" "  Kubeconfig path: ${kubeconfig_path}"
  assert_contains "${output}" "  OpenClaw URL: http://openclaw.localtest.me"
  assert_contains "${output}" "  Gitea URL: http://gitea.localtest.me"
  assert_contains "${output}" "  Infisical URL: http://infisical.localtest.me"

  case "${case_name}" in
    default-token)
      assert_contains "${output}" "  OpenClaw gateway token: local-dev-token"
      ;;
    explicit-token)
      assert_contains "${output}" "  OpenClaw gateway token: ${token_value}"
      ;;
    *)
      printf 'unknown case_name: %s\n' "${case_name}" >&2
      exit 1
      ;;
  esac

  assert_contains "$(cat "${command_log}")" "k3d-bootstrap-secrets.sh --namespace test-namespace --release-name test-release --kubeconfig ${kubeconfig_path}"

  trap - RETURN
  rm -rf "${sandbox_dir}"
}

run_case default-token ""
run_case explicit-token "test-gateway-token"

echo "k3d local bootstrap tests passed"
