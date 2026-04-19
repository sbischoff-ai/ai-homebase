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
fake_bin="${sandbox_dir}/bin"
mkdir -p "${repo_dir}/scripts/lib" "${fake_bin}"

cp "${REPO_ROOT}/scripts/k3s-down.sh" "${repo_dir}/scripts/k3s-down.sh"
cp "${REPO_ROOT}/scripts/bootstrap-config.py" "${repo_dir}/scripts/bootstrap-config.py"
cp "${REPO_ROOT}/scripts/lib/bootstrap-hosts.sh" "${repo_dir}/scripts/lib/bootstrap-hosts.sh"
cp "${REPO_ROOT}/scripts/lib/logging.sh" "${repo_dir}/scripts/lib/logging.sh"
chmod +x "${repo_dir}/scripts/k3s-down.sh" "${repo_dir}/scripts/bootstrap-config.py"

cat >"${sandbox_dir}/bootstrap.local.toml" <<'EOF'
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

[mail]
domain = "example.com"
smtp_host = "smtp.example.com"

[services.gitea.actions]
enabled = true
vm_name = "actions-vm"
host_alias = "actions.test.internal"
ssh_port = 2227
labels = ["linux-amd64", "homebase-coder"]
EOF

cat >"${fake_bin}/sudo" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'sudo %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
exec "$@"
SH

cat >"${fake_bin}/systemctl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'systemctl %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
exit 0
SH

cat >"${fake_bin}/incus" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'incus %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
if [[ "$1" == "info" ]]; then
  exit 0
fi
if [[ "$1" == "stop" ]]; then
  exit 0
fi
exit 0
SH

chmod +x "${fake_bin}/sudo" "${fake_bin}/systemctl" "${fake_bin}/incus"

(
  cd "${repo_dir}"
  export PATH="${fake_bin}:${PATH}"
  export FAKE_COMMAND_LOG="${sandbox_dir}/commands.log"
  ./scripts/k3s-down.sh --bootstrap-config "${sandbox_dir}/bootstrap.local.toml" >"${sandbox_dir}/output.log"
)

commands="$(cat "${sandbox_dir}/commands.log")"
output="$(cat "${sandbox_dir}/output.log")"

assert_contains "${commands}" "incus info openclaw-sandbox"
assert_contains "${commands}" "incus stop openclaw-sandbox --force"
assert_contains "${commands}" "incus info actions-vm"
assert_contains "${commands}" "incus stop actions-vm --force"
assert_contains "${commands}" "systemctl stop k3s"
assert_contains "${output}" "k3s runtime has been stopped."
assert_contains "${output}" "Durable host state, Incus definitions, and installed binaries were left in place."

echo "k3s down tests passed"
