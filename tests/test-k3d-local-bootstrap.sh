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
  local fake_bin="${sandbox_dir}/bin"
  mkdir -p "${repo_dir}/scripts/lib"
  mkdir -p "${fake_bin}"
  cp "${REPO_ROOT}/scripts/bootstrap-runtime-k3d.sh" "${repo_dir}/scripts/bootstrap-runtime-k3d.sh"
  cp "${REPO_ROOT}/scripts/bootstrap-config.py" "${repo_dir}/scripts/bootstrap-config.py"
  cp "${REPO_ROOT}/scripts/lib/bootstrap-hosts.sh" "${repo_dir}/scripts/lib/bootstrap-hosts.sh"
  cp "${REPO_ROOT}/scripts/lib/logging.sh" "${repo_dir}/scripts/lib/logging.sh"
  chmod +x "${repo_dir}/scripts/bootstrap-runtime-k3d.sh"
  chmod +x "${repo_dir}/scripts/bootstrap-config.py"

  local command_log="${sandbox_dir}/commands.log"
  local kubeconfig_path="${sandbox_dir}/kubeconfig.yaml"
  local bootstrap_config_path="${sandbox_dir}/bootstrap.local.toml"
  local shared_state_source="${sandbox_dir}/openclaw-state"
  local incus_dir="${sandbox_dir}/.local/state/ai-homebase/incus"

  cat >"${bootstrap_config_path}" <<EOF
[providers]
openai_api_key = "test-openai-key"
anthropic_api_key = "test-anthropic-key"
gemini_api_key = "test-gemini-key"

[openclaw.agents.main]
model = "anthropic/claude-sonnet-4-6"

[openclaw.agents.coder]
model = "openai/gpt-5.4"

[openclaw.agents.architect]
model = "openai/gpt-5.4"

[openclaw.agents.watchdog]
model = "openai/gpt-5.4-nano"

[openclaw.agents.auditor]
model = "anthropic/claude-opus-4-7"

[hosts]
openclaw = "openclaw.test.internal"
nextcloud = "nextcloud.test.internal"
gitea = "gitea.test.internal"
registry = "registry.test.internal"
vaultwarden = "vaultwarden.test.internal"
paperless = "paperless.test.internal"

[mail]
domain = "example.com"
smtp_host = "smtp.example.com"

[admin]
name = "Test Admin"
username = "test-admin"
email = "admin@example.invalid"
password = "shared-admin-password"

[secrets]
openclaw_gateway_token = "${token_value}"
EOF

  for script_name in k3d-up.sh incus-vm-up.sh; do
    cat >"${repo_dir}/scripts/${script_name}" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s %s\n' "$(basename "$0")" "$*" >>"${FAKE_COMMAND_LOG:?}"
exit 0
SH
    chmod +x "${repo_dir}/scripts/${script_name}"
  done

  mkdir -p "${incus_dir}"
  cat >"${incus_dir}/openclaw-sandbox.env" <<'EOF'
HOST_LISTEN_ADDRESS=10.10.0.1
SSH_HOST_PORT=2222
EOF

  cat >"${fake_bin}/python3" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == "./scripts/bootstrap-config.py" && "$2" == "shell-vars" ]]; then
  cat <<'EOF'
GITEA_ACTIONS_ENABLED='false'
OPENCLAW_GATEWAY_TOKEN='test-gateway-token'
OPENCLAW_MAIN_MODEL='anthropic/claude-sonnet-4-6'
OPENCLAW_CODER_MODEL='openai/gpt-5.4'
OPENCLAW_ARCHITECT_MODEL='openai/gpt-5.4'
OPENCLAW_HOST='openclaw.test.internal'
NEXTCLOUD_HOST='nextcloud.test.internal'
GITEA_HOST='gitea.test.internal'
REGISTRY_HOST='registry.test.internal'
VAULTWARDEN_HOST='vaultwarden.test.internal'
PAPERLESS_HOST='paperless.test.internal'
EOF
  exit 0
fi
printf 'unexpected python3 invocation: %s\n' "$*" >&2
exit 1
SH
  chmod +x "${fake_bin}/python3"

  local output_file="${sandbox_dir}/output.log"
  (
    cd "${repo_dir}"
    export FAKE_COMMAND_LOG="${command_log}"
    export HOME="${sandbox_dir}"
    export PATH="${fake_bin}:${PATH}"

    ./scripts/bootstrap-runtime-k3d.sh \
      --cluster-name test-cluster \
      --namespace test-namespace \
      --release-name test-release \
      --kubeconfig "${kubeconfig_path}" \
      --bootstrap-config "${bootstrap_config_path}" \
      --shared-openclaw-state-source "${shared_state_source}"
  ) >"${output_file}" 2>&1

  local output commands
  output="$(cat "${output_file}")"
  commands="$(cat "${command_log}")"

  assert_contains "${output}" "k3d runtime is ready."
  assert_contains "${output}" "  Kubeconfig path: ${kubeconfig_path}"
  assert_contains "${output}" "  Next step: ./scripts/bootstrap-stack.sh --profile k3d --bootstrap-config ${bootstrap_config_path} --kubeconfig ${kubeconfig_path} --shared-openclaw-state-source ${shared_state_source}"
  assert_contains "${commands}" "k3d-up.sh --cluster-name test-cluster --kubeconfig ${kubeconfig_path} --shared-openclaw-state-source ${shared_state_source} --shared-openclaw-state-target /var/lib/ai-homebase/openclaw-state"
  assert_contains "${commands}" "incus-vm-up.sh --vm-name openclaw-sandbox --shared-openclaw-state-source ${shared_state_source} --shared-openclaw-state-target /home/node/.openclaw --resolve-host openclaw.test.internal --resolve-host nextcloud.test.internal --resolve-host gitea.test.internal --resolve-host registry.test.internal --resolve-host vaultwarden.test.internal --resolve-host paperless.test.internal"

  trap - RETURN
  rm -rf "${sandbox_dir}"
}

run_case default-token ""
run_case explicit-token test-gateway-token

echo "k3d runtime tests passed"
