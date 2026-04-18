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
cp "${REPO_ROOT}/scripts/bootstrap-openclaw-skills.sh" "${repo_dir}/scripts/bootstrap-openclaw-skills.sh"
chmod +x "${repo_dir}/scripts/bootstrap-openclaw-skills.sh"

cat >"${sandbox_dir}/bin/kubectl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'kubectl %s\n' "$*" >>"${FAKE_KUBECTL_LOG:?}"
case "$*" in
  *"rollout status"*) exit 0 ;;
  *"exec deployment/platform-stack-openclaw"*) exit 0 ;;
esac
SH
chmod +x "${sandbox_dir}/bin/kubectl"

(
  cd "${repo_dir}"
  export PATH="${sandbox_dir}/bin:${PATH}"
  export FAKE_KUBECTL_LOG="${sandbox_dir}/kubectl.log"
  ./scripts/bootstrap-openclaw-skills.sh --release-name platform-stack --namespace ai-homebase >"${sandbox_dir}/output.log"
)

kubectl_log="$(cat "${sandbox_dir}/kubectl.log")"
output="$(cat "${sandbox_dir}/output.log")"

assert_contains "${kubectl_log}" "rollout status deployment/platform-stack-openclaw --timeout 600s"
assert_contains "${kubectl_log}" "openclaw skills info github"
assert_contains "${kubectl_log}" "openclaw skills info summarize"
assert_contains "${kubectl_log}" "openclaw skills info tmux"
assert_contains "${kubectl_log}" "reviewer-gitea-init.sh"
assert_contains "${kubectl_log}" "tea repo list --login"
assert_contains "${output}" "Checking OpenClaw skill setup: github"
assert_contains "${output}" "Checking OpenClaw skill setup: summarize"
assert_contains "${output}" "Checking OpenClaw skill setup: tmux"
assert_contains "${output}" "Checking OpenClaw skill setup: reviewer-gitea"

echo "bootstrap OpenClaw skills tests passed"
