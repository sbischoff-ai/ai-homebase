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

sandbox_dir="$(mktemp -d)"
trap 'rm -rf "${sandbox_dir}"' EXIT

repo_dir="${sandbox_dir}/repo"
mkdir -p "${repo_dir}/scripts/lib"
cp "${REPO_ROOT}/scripts/k3s-homelab-sandbox-up.sh" "${repo_dir}/scripts/k3s-homelab-sandbox-up.sh"
cp "${REPO_ROOT}/scripts/bootstrap-config.py" "${repo_dir}/scripts/bootstrap-config.py"
cp "${REPO_ROOT}/scripts/lib/logging.sh" "${repo_dir}/scripts/lib/logging.sh"
chmod +x "${repo_dir}/scripts/k3s-homelab-sandbox-up.sh" "${repo_dir}/scripts/bootstrap-config.py"

cat >"${sandbox_dir}/bootstrap.local.toml" <<'EOF'
[providers]
openai_api_key = "test-openai-key"
anthropic_api_key = "test-anthropic-key"

[openclaw.agents.main]
model = "anthropic/claude-sonnet-4-6"

[openclaw.agents.coder]
model = "anthropic/claude-sonnet-4-5"

[openclaw.agents.architect]
model = "anthropic/claude-opus-4-6"

[openclaw.agents.watchdog]
model = "anthropic/claude-haiku-4-5"

[hosts]
openclaw = "openclaw.test.internal"
nextcloud_mcp = "nextcloud-mcp.test.internal"
gitea = "gitea.test.internal"
registry = "registry.test.internal"

[mail]
domain = "example.com"
smtp_host = "smtp.example.com"
EOF

cat >"${repo_dir}/scripts/incus-vm-up.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'incus-vm-up.sh %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
SH
chmod +x "${repo_dir}/scripts/incus-vm-up.sh"

(
  cd "${repo_dir}"
  export FAKE_COMMAND_LOG="${sandbox_dir}/commands.log"
  ./scripts/k3s-homelab-sandbox-up.sh --bootstrap-config "${sandbox_dir}/bootstrap.local.toml" >"${sandbox_dir}/output.log"
)

commands="$(cat "${sandbox_dir}/commands.log")"
output="$(cat "${sandbox_dir}/output.log")"

assert_contains "${commands}" "--vm-name openclaw-sandbox"
assert_contains "${commands}" "--host-alias openclaw-sandbox.homebase.internal"
assert_contains "${commands}" "--shared-openclaw-state-source /var/lib/ai-homebase/openclaw-state"
assert_contains "${commands}" "--shared-openclaw-state-target /home/node/.openclaw"
assert_contains "${commands}" "--resolve-host openclaw.test.internal"
assert_contains "${commands}" "--resolve-host nextcloud-mcp.test.internal"
assert_contains "${commands}" "--resolve-host gitea.test.internal"
assert_contains "${commands}" "--resolve-host registry.test.internal"
assert_contains "${output}" "Homelab sandbox VM is ready."
assert_contains "${output}" "Gitea host override inside sandbox: gitea.test.internal"
assert_contains "${output}" "Registry host override inside sandbox: registry.test.internal"
assert_contains "${output}" "OpenClaw host override inside sandbox: openclaw.test.internal"
assert_contains "${output}" "Shared OpenClaw state: /var/lib/ai-homebase/openclaw-state -> /home/node/.openclaw"

echo "k3s homelab sandbox tests passed"
