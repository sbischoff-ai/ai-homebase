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
mkdir -p "${repo_dir}/scripts" "${repo_dir}/charts/platform-stack"
cp "${REPO_ROOT}/scripts/bootstrap-stack.sh" "${repo_dir}/scripts/bootstrap-stack.sh"
cp "${REPO_ROOT}/scripts/bootstrap-config.py" "${repo_dir}/scripts/bootstrap-config.py"
chmod +x "${repo_dir}/scripts/bootstrap-stack.sh" "${repo_dir}/scripts/bootstrap-config.py"

cat >"${repo_dir}/charts/platform-stack/values.yaml" <<'EOF'
openclaw:
  remoteDocker:
    dockerHost: ssh://docker-remote@openclaw-sandbox.homebase.internal:2222
EOF

cat >"${repo_dir}/charts/platform-stack/values-k3s.yaml" <<'EOF'
openclaw:
  remoteDocker:
    dockerHost: ssh://docker-remote@openclaw-sandbox.homebase.internal:2222
EOF

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

[mail]
domain = "example.com"
smtp_host = "smtp.example.com"
EOF

mkdir -p "${sandbox_dir}/bin" "${sandbox_dir}/incus"
cat >"${sandbox_dir}/incus/openclaw-sandbox.env" <<'EOF'
HOST_LISTEN_ADDRESS=10.10.10.1
SSH_HOST_PORT=2222
EOF

cat >"${repo_dir}/scripts/bootstrap-secrets.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'bootstrap-secrets.sh %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
SH
chmod +x "${repo_dir}/scripts/bootstrap-secrets.sh"

cat >"${repo_dir}/scripts/build-openclaw-sandbox-images.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'build-openclaw-sandbox-images.sh %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
SH
chmod +x "${repo_dir}/scripts/build-openclaw-sandbox-images.sh"

cat >"${repo_dir}/scripts/openclaw-remote-docker-load-images.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'openclaw-remote-docker-load-images.sh %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
SH
chmod +x "${repo_dir}/scripts/openclaw-remote-docker-load-images.sh"

cat >"${repo_dir}/scripts/bootstrap-coder-gitea.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'bootstrap-coder-gitea.sh %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
SH
chmod +x "${repo_dir}/scripts/bootstrap-coder-gitea.sh"

cat >"${sandbox_dir}/bin/helm" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'helm %s\n' "$*" >>"${FAKE_HELM_LOG:?}"
if [[ "$1" == "upgrade" ]]; then
  prev=""
  for arg in "$@"; do
    if [[ "$prev" == "--values" && -f "$arg" ]]; then
      printf -- '--- values file: %s ---\n' "$arg" >>"${FAKE_HELM_LOG:?}"
      cat "$arg" >>"${FAKE_HELM_LOG:?}"
      printf '\n' >>"${FAKE_HELM_LOG:?}"
    fi
    prev="$arg"
  done
fi
if [[ "$1" == "dependency" ]]; then
  exit 0
fi
if [[ "$1" == "template" ]]; then
  printf 'kind: ConfigMap\nmetadata:\n  labels:\n    helm.sh/chart: openclaw-0.1.0\n'
  exit 0
fi
exit 0
SH

cat >"${sandbox_dir}/bin/kubectl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'kubectl %s\n' "$*" >>"${FAKE_KUBECTL_LOG:?}"
exit 0
SH

chmod +x "${sandbox_dir}/bin/helm" "${sandbox_dir}/bin/kubectl"

(
  cd "${repo_dir}"
  export PATH="${sandbox_dir}/bin:${PATH}"
  export HOME="${sandbox_dir}"
  export FAKE_COMMAND_LOG="${sandbox_dir}/commands.log"
  export FAKE_HELM_LOG="${sandbox_dir}/helm.log"
  export FAKE_KUBECTL_LOG="${sandbox_dir}/kubectl.log"
  ./scripts/bootstrap-stack.sh \
    --profile k3s \
    --bootstrap-config "${sandbox_dir}/bootstrap.local.toml" \
    --incus-connection-info "${sandbox_dir}/incus/openclaw-sandbox.env"
)

commands="$(cat "${sandbox_dir}/commands.log")"
helm_log="$(cat "${sandbox_dir}/helm.log")"

assert_contains "${commands}" "--remote-docker-host 10.10.10.1"
assert_contains "${commands}" "--remote-docker-port 2222"
assert_contains "${commands}" "build-openclaw-sandbox-images.sh --coder-image openclaw-sandbox-coder:bookworm-slim"
assert_contains "${commands}" "openclaw-remote-docker-load-images.sh --docker-host ssh://docker-remote@10.10.10.1:2222 --image openclaw-sandbox-coder:bookworm-slim"
assert_contains "${commands}" "bootstrap-coder-gitea.sh --bootstrap-config ${sandbox_dir}/bootstrap.local.toml --release-name platform-stack --namespace ai-homebase"
assert_contains "${helm_log}" "dockerHost: ssh://docker-remote@10.10.10.1:2222"

echo "bootstrap stack remote docker autodiscovery tests passed"
