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
mkdir -p "${repo_dir}/scripts"
cp "${REPO_ROOT}/scripts/bootstrap-gitops.sh" "${repo_dir}/scripts/bootstrap-gitops.sh"
cp "${REPO_ROOT}/scripts/bootstrap-stack.sh" "${repo_dir}/scripts/bootstrap-stack.sh"
cp "${REPO_ROOT}/scripts/bootstrap-config.py" "${repo_dir}/scripts/bootstrap-config.py"
chmod +x "${repo_dir}/scripts/bootstrap-gitops.sh" "${repo_dir}/scripts/bootstrap-stack.sh" "${repo_dir}/scripts/bootstrap-config.py"

bootstrap_config_path="${sandbox_dir}/bootstrap.local.toml"
command_log="${sandbox_dir}/commands.log"
kubectl_log="${sandbox_dir}/kubectl.log"
curl_log="${sandbox_dir}/curl.log"
git_log="${sandbox_dir}/git.log"

cat >"${bootstrap_config_path}" <<'EOF'
[providers]
openai_api_key = "test-openai-key"
anthropic_api_key = "test-anthropic-key"

[openclaw.agents.main]
model = "anthropic/claude-sonnet-4-6"

[openclaw.agents.coder]
model = "openai/gpt-5.4"

[openclaw.agents.coder.gitea]
username = "coder-bot"
password = "explicit-coder-password"

[openclaw.agents.architect]
model = "anthropic/claude-opus-4-6"

[hosts]
openclaw = "openclaw.test.internal"
nextcloud = "nextcloud.test.internal"
gitea = "gitea.test.internal"
argocd = "argocd.test.internal"
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

[gitops]
cluster_name = "lab-cluster"
repo_name = "cluster-gitops"
repo_branch = "main"
project = "platform-stack"
EOF

cat >"${repo_dir}/scripts/bootstrap-secrets.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'bootstrap-secrets.sh %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
SH
chmod +x "${repo_dir}/scripts/bootstrap-secrets.sh"

cat >"${repo_dir}/scripts/bootstrap-stack.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'bootstrap-stack.sh %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
SH
chmod +x "${repo_dir}/scripts/bootstrap-stack.sh"

cat >"${repo_dir}/scripts/render-gitops-repo.py" <<'PY'
#!/usr/bin/env python3
from pathlib import Path
import sys

args = sys.argv[1:]
output_dir = Path(args[args.index("--output-dir") + 1])
cluster_name = args[args.index("--cluster-name") + 1]
(output_dir / "gitops" / "clusters" / cluster_name / "applications").mkdir(parents=True, exist_ok=True)
(output_dir / "gitops" / "clusters" / cluster_name / "project.yaml").write_text("kind: AppProject\nmetadata:\n  name: platform-stack\n")
(output_dir / "gitops" / "clusters" / cluster_name / "applications" / "platform-stack.yaml").write_text("kind: Application\nmetadata:\n  name: platform-stack-platform-stack\n")
(output_dir / "gitops" / "clusters" / cluster_name / "root-application.yaml").write_text("kind: Application\nmetadata:\n  name: platform-stack-gitops-root\n")
PY
chmod +x "${repo_dir}/scripts/render-gitops-repo.py"

mkdir -p "${sandbox_dir}/bin"

cat >"${sandbox_dir}/bin/helm" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'helm %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
if [[ "$1" == "status" ]]; then
  exit 0
fi
exit 0
SH

cat >"${sandbox_dir}/bin/kubectl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'kubectl %s\n' "$*" >>"${FAKE_KUBECTL_LOG:?}"
case "$*" in
  *"get secret gitea-admin-secret -o jsonpath={.data.username}"*) printf 'aG9tZWJhc2UtYWRtaW4=' ;;
  *"get secret gitea-admin-secret -o jsonpath={.data.password}"*) printf 'YWRtaW4tcGFzcw==' ;;
  *"get secret gitops-config-secrets -o jsonpath={.data.CODER_GITEA_PASSWORD}"*) exit 1 ;;
  *"get secret gitops-config-secrets -o jsonpath={.data.GITOPS_ROBOT_PASSWORD}"*) exit 1 ;;
  *) ;;
esac
exit 0
SH

cat >"${sandbox_dir}/bin/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'curl %s\n' "$*" >>"${FAKE_CURL_LOG:?}"
case "$*" in
  *"/users/coder-bot"*) printf '404' ;;
  *"/repos/coder-bot/cluster-gitops"*) printf '404' ;;
  *"/api/v1/version"*) printf '{"version":"1.0"}' ;;
  *) printf '{}' ;;
esac
exit 0
SH

cat >"${sandbox_dir}/bin/git" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'git %s\n' "$*" >>"${FAKE_GIT_LOG:?}"
exit 0
SH

chmod +x "${sandbox_dir}/bin/helm" "${sandbox_dir}/bin/kubectl" "${sandbox_dir}/bin/curl" "${sandbox_dir}/bin/git"

output_file="${sandbox_dir}/output.log"
remote_docker_key_path="${sandbox_dir}/openclaw-sandbox-id_ed25519"
touch "${remote_docker_key_path}"
set +e
(
  cd "${repo_dir}"
  export PATH="${sandbox_dir}/bin:${PATH}"
  export FAKE_COMMAND_LOG="${command_log}"
  export FAKE_KUBECTL_LOG="${kubectl_log}"
  export FAKE_CURL_LOG="${curl_log}"
  export FAKE_GIT_LOG="${git_log}"

  ./scripts/bootstrap-gitops.sh \
    --profile k3d \
    --bootstrap-config "${bootstrap_config_path}" \
    --remote-docker-key "${remote_docker_key_path}"
) >"${output_file}" 2>&1
status=$?
set -e

if [[ "${status}" -ne 0 ]]; then
  cat "${output_file}" >&2
  cat "${command_log}" >&2 || true
  cat "${kubectl_log}" >&2 || true
  cat "${curl_log}" >&2 || true
  cat "${git_log}" >&2 || true
  exit "${status}"
fi

output="$(cat "${output_file}")"
commands="$(cat "${command_log}")"
kubectl_output="$(cat "${kubectl_log}")"
curl_output="$(cat "${curl_log}")"
git_output="$(cat "${git_log}")"

assert_contains "${commands}" "bootstrap-stack.sh --profile k3d --bootstrap-config ${bootstrap_config_path} --release-name platform-stack --namespace ai-homebase --skip-secrets --enable-service argo-cd"
assert_contains "${commands}" "bootstrap-secrets.sh --profile k3d --bootstrap-config ${bootstrap_config_path} --release-name platform-stack --namespace ai-homebase"
assert_contains "${commands}" "--remote-docker-key ${remote_docker_key_path}"
assert_contains "${curl_output}" "/api/v1/admin/users"
assert_contains "${curl_output}" "/api/v1/user/repos"
assert_contains "${kubectl_output}" "root-application.yaml"
assert_contains "${git_output}" "push --force origin HEAD:main"
assert_contains "${output}" "GitOps bootstrap complete."
assert_contains "${output}" "Argo CD URL: http://argocd.test.internal"

echo "bootstrap gitops tests passed"
