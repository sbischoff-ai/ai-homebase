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
mkdir -p "${repo_dir}/scripts" "${sandbox_dir}/bin"
cp "${REPO_ROOT}/scripts/bootstrap-coder-gitea.sh" "${repo_dir}/scripts/bootstrap-coder-gitea.sh"
cp "${REPO_ROOT}/scripts/bootstrap-config.py" "${repo_dir}/scripts/bootstrap-config.py"
chmod +x "${repo_dir}/scripts/bootstrap-coder-gitea.sh" "${repo_dir}/scripts/bootstrap-config.py"

cat >"${sandbox_dir}/bootstrap.local.toml" <<'EOF'
[providers]
openai_api_key = "test-openai-key"
anthropic_api_key = "test-anthropic-key"

[openclaw.agents.main]
model = "anthropic/claude-sonnet-4-6"

[openclaw.agents.coder]
model = "openai/gpt-5.4"

[openclaw.agents.coder.gitea]
username = "coder-bot"
email = "coder@example.invalid"
password = "coder-password"

[openclaw.agents.architect]
model = "anthropic/claude-opus-4-6"

[hosts]
gitea = "gitea.test.internal"

[mail]
domain = "example.com"
smtp_host = "smtp.example.com"
EOF

cat >"${sandbox_dir}/bin/kubectl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'kubectl %s\n' "$*" >>"${FAKE_KUBECTL_LOG:?}"
case "$*" in
  *"get secret gitea-admin-secret -o jsonpath={.data.username}"*) printf 'YWRtaW4=' ;;
  *"get secret gitea-admin-secret -o jsonpath={.data.password}"*) printf 'YWRtaW4tcGFzcw==' ;;
esac
SH

cat >"${sandbox_dir}/bin/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'curl %s\n' "$*" >>"${FAKE_CURL_LOG:?}"
case "$*" in
  *"/api/v1/users/coder-bot"*)
    printf '404'
    ;;
  *"/api/v1/admin/users"*)
    printf '{}'
    ;;
  *)
    printf '{}'
    ;;
esac
SH

chmod +x "${sandbox_dir}/bin/kubectl" "${sandbox_dir}/bin/curl"

(
  cd "${repo_dir}"
  export PATH="${sandbox_dir}/bin:${PATH}"
  export FAKE_KUBECTL_LOG="${sandbox_dir}/kubectl.log"
  export FAKE_CURL_LOG="${sandbox_dir}/curl.log"
  ./scripts/bootstrap-coder-gitea.sh --bootstrap-config "${sandbox_dir}/bootstrap.local.toml" >"${sandbox_dir}/output.log"
)

output="$(cat "${sandbox_dir}/output.log")"
kubectl_log="$(cat "${sandbox_dir}/kubectl.log")"
curl_log="$(cat "${sandbox_dir}/curl.log")"

assert_contains "${kubectl_log}" "get secret gitea-admin-secret -o jsonpath={.data.username}"
assert_contains "${curl_log}" "/api/v1/users/coder-bot"
assert_contains "${curl_log}" "/api/v1/admin/users"
assert_contains "${output}" "Coder Gitea user coder-bot is ready at https://gitea.test.internal."

echo "bootstrap coder gitea tests passed"
