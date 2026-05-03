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
mkdir -p "${repo_dir}/scripts/lib" "${fake_bin}" "${sandbox_dir}/shared-state" "${sandbox_dir}/etc/rancher/k3s"

cp "${REPO_ROOT}/scripts/bootstrap-runtime-k3s.sh" "${repo_dir}/scripts/bootstrap-runtime-k3s.sh"
cp "${REPO_ROOT}/scripts/bootstrap-config.py" "${repo_dir}/scripts/bootstrap-config.py"
cp "${REPO_ROOT}/scripts/lib/bootstrap-hosts.sh" "${repo_dir}/scripts/lib/bootstrap-hosts.sh"
cp "${REPO_ROOT}/scripts/lib/ingress-nginx.sh" "${repo_dir}/scripts/lib/ingress-nginx.sh"
cp "${REPO_ROOT}/scripts/lib/logging.sh" "${repo_dir}/scripts/lib/logging.sh"
chmod +x "${repo_dir}/scripts/bootstrap-runtime-k3s.sh" "${repo_dir}/scripts/bootstrap-config.py"

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
nextcloud = "nextcloud.test.internal"
nextcloud_mcp = "nextcloud-mcp.test.internal"
qdrant = "qdrant.test.internal"
qdrant_mcp = "qdrant-mcp.test.internal"
memgraph = "memgraph.test.internal"
memgraph_lab = "memgraph-lab.test.internal"
gitea = "gitea.test.internal"
registry = "registry.test.internal"
vaultwarden = "vaultwarden.test.internal"
paperless = "paperless.test.internal"

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

cat >"${repo_dir}/scripts/incus-vm-up.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'incus-vm-up.sh %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
SH
chmod +x "${repo_dir}/scripts/incus-vm-up.sh"

cat >"${fake_bin}/sudo" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'sudo %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -u)
      shift 2
      ;;
    -H)
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done
exec "$@"
SH

cat >"${fake_bin}/systemctl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'systemctl %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
exit 0
SH

cat >"${fake_bin}/kubectl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'kubectl %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
if [[ "$1" == "--kubeconfig" ]]; then
  shift 2
fi
if [[ "$1" == "-n" ]]; then
  namespace="$2"
  shift 2
else
  namespace=""
fi
case "$1" in
  wait)
    exit 0
    ;;
  get)
    if [[ "${namespace}" == "kube-system" && "${2:-}" == "deployment" && "${3:-}" == "traefik" ]]; then
      exit 1
    fi
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
SH

cat >"${fake_bin}/helm" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'helm %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
exit 0
SH

cat >"${fake_bin}/incus" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'incus %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
case "$1 $2 $3" in
  "profile show default")
    exit 1
    ;;
  "network show incusbr0")
    exit 1
    ;;
  "storage show default")
    exit 1
    ;;
  "profile device get")
    exit 1
    ;;
  *)
    exit 0
    ;;
esac
SH

cat >"${fake_bin}/k3s" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
exit 0
SH

cat >"${fake_bin}/python3" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == "./scripts/bootstrap-config.py" && "$2" == "shell-vars" ]]; then
  cat <<'EOF'
GITEA_ACTIONS_ENABLED='true'
GITEA_ACTIONS_RUNNER_VM_NAME='actions-vm'
GITEA_ACTIONS_RUNNER_HOST_ALIAS='actions.test.internal'
GITEA_ACTIONS_RUNNER_SSH_PORT='2227'
OPENCLAW_HOST='openclaw.test.internal'
NEXTCLOUD_HOST='nextcloud.test.internal'
NEXTCLOUD_MCP_HOST='nextcloud-mcp.test.internal'
QDRANT_HOST='qdrant.test.internal'
QDRANT_MCP_HOST='qdrant-mcp.test.internal'
MEMGRAPH_HOST='memgraph.test.internal'
MEMGRAPH_LAB_HOST='memgraph-lab.test.internal'
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

chmod +x \
  "${fake_bin}/sudo" \
  "${fake_bin}/systemctl" \
  "${fake_bin}/kubectl" \
  "${fake_bin}/helm" \
  "${fake_bin}/incus" \
  "${fake_bin}/k3s" \
  "${fake_bin}/python3"

(
  cd "${repo_dir}"
  export PATH="${fake_bin}:${PATH}"
  export FAKE_COMMAND_LOG="${sandbox_dir}/commands.log"
  export K3S_CONFIG_DIR="${sandbox_dir}/etc/rancher/k3s/config.yaml.d"
  export K3S_CONFIG_PATH="${K3S_CONFIG_DIR}/10-ai-homebase.yaml"
  export K3S_KUBECONFIG="${sandbox_dir}/etc/rancher/k3s/k3s.yaml"
  ./scripts/bootstrap-runtime-k3s.sh \
    --bootstrap-config "${sandbox_dir}/bootstrap.local.toml" \
    --openclaw-shared-state-dir "${sandbox_dir}/shared-state" \
    >"${sandbox_dir}/output.log"
)

commands="$(cat "${sandbox_dir}/commands.log")"
output="$(cat "${sandbox_dir}/output.log")"
config_contents="$(cat "${sandbox_dir}/etc/rancher/k3s/config.yaml.d/10-ai-homebase.yaml")"

assert_contains "${commands}" "systemctl enable --now k3s"
assert_contains "${commands}" "systemctl restart k3s"
assert_contains "${commands}" "kubectl --kubeconfig ${sandbox_dir}/etc/rancher/k3s/k3s.yaml wait --for=condition=Ready node --all --timeout=180s"
assert_contains "${commands}" "helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --kubeconfig ${sandbox_dir}/etc/rancher/k3s/k3s.yaml --namespace ingress-nginx --create-namespace --hide-notes --set controller.ingressClassResource.name=nginx --set controller.ingressClass=nginx --set controller.watchIngressWithoutClass=false --set tcp.7687=ai-homebase/platform-stack-memgraph:7687"
assert_contains "${commands}" "incus admin init --auto"
assert_contains "${commands}" "incus network create incusbr0 ipv4.address=10.10.10.1/24 ipv4.nat=true ipv6.address=none"
assert_contains "${commands}" "incus storage create default dir"
assert_contains "${commands}" "incus profile device add default root disk path=/ pool=default"
assert_contains "${commands}" "incus profile device add default eth0 nic network=incusbr0 name=eth0"
assert_contains "${commands}" "incus-vm-up.sh --vm-name openclaw-sandbox --host-alias openclaw-sandbox.homebase.internal --shared-openclaw-state-source ${sandbox_dir}/shared-state --shared-openclaw-state-target /home/node/.openclaw"
assert_contains "${commands}" "--resolve-host openclaw.test.internal"
assert_contains "${commands}" "--resolve-host nextcloud.test.internal"
assert_contains "${commands}" "--resolve-host nextcloud-mcp.test.internal"
assert_contains "${commands}" "--resolve-host qdrant.test.internal"
assert_contains "${commands}" "--resolve-host qdrant-mcp.test.internal"
assert_contains "${commands}" "--resolve-host gitea.test.internal"
assert_contains "${commands}" "--resolve-host registry.test.internal"
assert_contains "${commands}" "--resolve-host vaultwarden.test.internal"
assert_contains "${commands}" "--resolve-host paperless.test.internal"
assert_contains "${commands}" "incus-vm-up.sh --vm-name actions-vm --host-alias actions.test.internal --ssh-host-port 2227 --ssh-key-path ${HOME}/.local/state/ai-homebase/incus/actions-vm-id_ed25519 --remote-user-gecos Gitea Actions runner Docker user"
assert_contains "${config_contents}" 'write-kubeconfig-mode: "644"'
assert_contains "${config_contents}" "disable:"
assert_contains "${config_contents}" "  - traefik"
assert_contains "${output}" "k3s runtime is ready."
assert_contains "${output}" "./scripts/bootstrap-stack.sh --profile k3s --bootstrap-config ${sandbox_dir}/bootstrap.local.toml --shared-openclaw-state-source ${sandbox_dir}/shared-state"

echo "k3s runtime tests passed"
