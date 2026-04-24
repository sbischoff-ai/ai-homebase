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

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "${haystack}" == *"${needle}"* ]]; then
    printf 'expected output to omit: %s\n' "${needle}" >&2
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
runtime_root="${sandbox_dir}/runtime-root"
mkdir -p "${runtime_root}"
sed -i "s#/home/node/.openclaw#${runtime_root}#g" "${repo_dir}/scripts/bootstrap-openclaw-skills.sh"

cat >"${sandbox_dir}/bin/kubectl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'kubectl %s\n' "$*" >>"${FAKE_KUBECTL_LOG:?}"
case "$*" in
  *"rollout status"*) exit 0 ;;
  *"exec -c openclaw deployment/platform-stack-openclaw"*)
    args=("$@")
    for i in "${!args[@]}"; do
      if [[ "${args[$i]}" == "--" ]]; then
        __ETC_BASHLOGOUT_SOURCED=1 PATH="${FAKE_BIN_DIR:?}:${PATH}" "${args[@]:$((i + 1))}"
        exit 0
      fi
    done
    exit 0
    ;;
esac
SH
chmod +x "${sandbox_dir}/bin/kubectl"

cat >"${sandbox_dir}/bin/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'gh %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
case "${1:-}" in
  auth) exit 0 ;;
esac
exit 0
SH
chmod +x "${sandbox_dir}/bin/gh"

cat >"${sandbox_dir}/bin/openclaw" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'openclaw %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
exit 0
SH
chmod +x "${sandbox_dir}/bin/openclaw"

cat >"${sandbox_dir}/bin/summarize" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'summarize %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
exit 0
SH
chmod +x "${sandbox_dir}/bin/summarize"

cat >"${sandbox_dir}/bin/tmux" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'tmux %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
exit 0
SH
chmod +x "${sandbox_dir}/bin/tmux"

cat >"${sandbox_dir}/bin/reviewer-gitea-init.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'reviewer-gitea-init.sh %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
exit 0
SH
chmod +x "${sandbox_dir}/bin/reviewer-gitea-init.sh"

cat >"${sandbox_dir}/bin/tea" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'tea %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
if [[ "${1:-}" == "login" && "${2:-}" == "list" ]]; then
  printf '%s\n' "${REVIEWER_GITEA_TEA_LOGIN_NAME:-reviewer}"
  exit 0
fi
if [[ "${1:-}" == "repo" && "${2:-}" == "view" && "${3:-}" == "${CODER_GITEA_USERNAME:-coder}/${CODER_GITOPS_REPO_NAME:-cluster-gitops}" && "${4:-}" == "--login" && "${5:-}" == "${REVIEWER_GITEA_TEA_LOGIN_NAME:-reviewer}" ]]; then
  printf '%s\n' "${CODER_GITOPS_REPO_NAME:-cluster-gitops}"
  exit 0
fi
SH
chmod +x "${sandbox_dir}/bin/tea"

cat >"${sandbox_dir}/bin/coder-workspace-init.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'coder-workspace-init.sh %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
mkdir -p "${CODEX_HOME:?}" "${XDG_CONFIG_HOME:?}/tea" "${DOCKER_CONFIG:?}"
printf '{}' > "${CODEX_HOME}/auth.json"
cat > "${XDG_CONFIG_HOME}/tea/config.yml" <<EOF
default: true
EOF
printf '{}' > "${DOCKER_CONFIG}/config.json"
exit 0
SH
chmod +x "${sandbox_dir}/bin/coder-workspace-init.sh"

run_case() {
  local phase="$1"
  local case_dir="${sandbox_dir}/${phase}"
  mkdir -p "${case_dir}"

  (
    cd "${repo_dir}"
    export PATH="${sandbox_dir}/bin:${PATH}"
    export FAKE_KUBECTL_LOG="${case_dir}/kubectl.log"
    export FAKE_COMMAND_LOG="${case_dir}/command.log"
    export FAKE_BIN_DIR="${sandbox_dir}/bin"
    export GITHUB_TOKEN="github-token"
    export OPENAI_API_KEY="openai-token"
    export REVIEWER_GITEA_BASE_URL="https://gitea.test.internal"
    export REVIEWER_GITEA_USERNAME="reviewer"
    export REVIEWER_GITEA_PASSWORD="reviewer-password"
    export REVIEWER_GITEA_TEA_LOGIN_NAME="reviewer"
    if [[ "$phase" == "post-gitops" ]]; then
      export CODER_GITEA_BASE_URL="https://gitea.test.internal"
      export CODER_GITEA_USERNAME="coder"
      export CODER_GITEA_TOKEN="coder-token"
      export CODER_REGISTRY_PASSWORD="registry-password"
      export REVIEWER_GITEA_TOKEN="reviewer-token"
    fi
    ./scripts/bootstrap-openclaw-skills.sh --release-name platform-stack --namespace ai-homebase --phase "$phase" >"${case_dir}/output.log"
  )
}

run_case pre-gitops
run_case post-gitops

pre_kubectl_log="$(cat "${sandbox_dir}/pre-gitops/kubectl.log")"
pre_command_log="$(cat "${sandbox_dir}/pre-gitops/command.log")"
pre_output="$(cat "${sandbox_dir}/pre-gitops/output.log")"
post_kubectl_log="$(cat "${sandbox_dir}/post-gitops/kubectl.log")"
post_command_log="$(cat "${sandbox_dir}/post-gitops/command.log")"
post_output="$(cat "${sandbox_dir}/post-gitops/output.log")"

assert_contains "${pre_kubectl_log}" "env OPENCLAW_SETUP_PHASE=pre-gitops sh -lc"
assert_contains "${post_kubectl_log}" "env OPENCLAW_SETUP_PHASE=post-gitops sh -lc"
assert_contains "${post_command_log}" "gh auth status"
assert_contains "${post_command_log}" "openclaw skills info github"
assert_contains "${post_command_log}" "openclaw skills info summarize"
assert_contains "${post_command_log}" "openclaw skills info tmux"
assert_not_contains "${pre_command_log}" "reviewer-gitea-init.sh"
assert_not_contains "${pre_command_log}" "tea login list"
assert_not_contains "${pre_command_log}" "tea repo list"
assert_not_contains "${pre_command_log}" "tea repo view"
assert_not_contains "${pre_command_log}" "coder-workspace-init.sh"
assert_contains "${post_command_log}" "reviewer-gitea-init.sh"
assert_contains "${post_command_log}" "tea login list"
assert_contains "${post_command_log}" "tea repo view coder/cluster-gitops --login reviewer"
assert_contains "${post_command_log}" "coder-workspace-init.sh"
assert_contains "${post_output}" "Checking OpenClaw skill setup: github"
assert_contains "${post_output}" "Checking OpenClaw skill setup: summarize"
assert_contains "${post_output}" "Checking OpenClaw skill setup: tmux"
assert_contains "${post_output}" "Checking OpenClaw skill setup: reviewer-gitea"
assert_contains "${post_output}" "Checking OpenClaw skill setup: coder-workspace"

echo "bootstrap OpenClaw skills tests passed"
