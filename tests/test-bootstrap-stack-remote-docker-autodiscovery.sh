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
cp "${REPO_ROOT}/scripts/bootstrap-stack.sh" "${repo_dir}/scripts/bootstrap-stack.sh"
cp "${REPO_ROOT}/scripts/lib/logging.sh" "${repo_dir}/scripts/lib/logging.sh"
chmod +x "${repo_dir}/scripts/bootstrap-stack.sh"

cat >"${repo_dir}/scripts/bootstrap-runtime-k3s.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'bootstrap-runtime-k3s.sh %s | log=%s\n' "$*" "${BOOTSTRAP_LOG_FILE:-}" >>"${FAKE_COMMAND_LOG:?}"
SH
chmod +x "${repo_dir}/scripts/bootstrap-runtime-k3s.sh"

cat >"${repo_dir}/scripts/bootstrap-apply.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'bootstrap-apply.sh %s | log=%s\n' "$*" "${BOOTSTRAP_LOG_FILE:-}" >>"${FAKE_COMMAND_LOG:?}"
SH
chmod +x "${repo_dir}/scripts/bootstrap-apply.sh"

cat >"${repo_dir}/scripts/bootstrap-smoke.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'bootstrap-smoke.sh %s | log=%s\n' "$*" "${BOOTSTRAP_LOG_FILE:-}" >>"${FAKE_COMMAND_LOG:?}"
SH
chmod +x "${repo_dir}/scripts/bootstrap-smoke.sh"

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
model = "anthropic/claude-haiku-4-5"

[openclaw.agents.auditor]
model = "anthropic/claude-opus-4-7"

[mail]
domain = "example.com"
smtp_host = "smtp.example.com"
EOF

mkdir -p "${sandbox_dir}/incus"
cat >"${sandbox_dir}/incus/openclaw-sandbox.env" <<'EOF'
HOST_LISTEN_ADDRESS=10.10.10.1
SSH_HOST_PORT=2222
EOF

(
  cd "${repo_dir}"
  export FAKE_COMMAND_LOG="${sandbox_dir}/commands.log"
  ./scripts/bootstrap-stack.sh \
    --profile k3s \
    --bootstrap-config "${sandbox_dir}/bootstrap.local.toml" \
    --incus-connection-info "${sandbox_dir}/incus/openclaw-sandbox.env"
)

commands="$(cat "${sandbox_dir}/commands.log")"
shared_log="$(printf '%s\n' "${commands}" | sed -n 's/.*| log=\(.*\)$/\1/p' | head -n 1)"

assert_contains "${commands}" "bootstrap-runtime-k3s.sh --bootstrap-config ${sandbox_dir}/bootstrap.local.toml"
assert_contains "${commands}" "bootstrap-apply.sh --profile k3s --bootstrap-config ${sandbox_dir}/bootstrap.local.toml --release-name platform-stack --namespace ai-homebase --kubeconfig ${HOME}/.kube/config --incus-vm-name openclaw-sandbox --incus-connection-info ${sandbox_dir}/incus/openclaw-sandbox.env"
assert_contains "${commands}" "bootstrap-smoke.sh --profile k3s --bootstrap-config ${sandbox_dir}/bootstrap.local.toml --release-name platform-stack --namespace ai-homebase --kubeconfig ${HOME}/.kube/config --incus-vm-name openclaw-sandbox --incus-connection-info ${sandbox_dir}/incus/openclaw-sandbox.env"

if [[ -z "${shared_log}" ]]; then
  printf 'expected bootstrap-stack to export a shared BOOTSTRAP_LOG_FILE\n' >&2
  printf 'command log:\n%s\n' "${commands}" >&2
  exit 1
fi

runtime_log="$(printf '%s\n' "${commands}" | sed -n '1s/.*| log=\(.*\)$/\1/p')"
apply_log="$(printf '%s\n' "${commands}" | sed -n '2s/.*| log=\(.*\)$/\1/p')"
smoke_log="$(printf '%s\n' "${commands}" | sed -n '3s/.*| log=\(.*\)$/\1/p')"

if [[ "${runtime_log}" != "${apply_log}" || "${apply_log}" != "${smoke_log}" ]]; then
  printf 'expected all bootstrap phases to share one log file\n' >&2
  printf 'command log:\n%s\n' "${commands}" >&2
  exit 1
fi

echo "bootstrap stack remote docker autodiscovery tests passed"
