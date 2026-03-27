#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_PATH="${REPO_ROOT}/scripts/openclaw-remote-docker-load-images.sh"

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
mkdir -p "${repo_dir}/scripts" "${fake_bin}"
cp "${SCRIPT_PATH}" "${repo_dir}/scripts/openclaw-remote-docker-load-images.sh"
chmod +x "${repo_dir}/scripts/openclaw-remote-docker-load-images.sh"

cat >"${fake_bin}/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'docker %s\n' "$*" >>"${FAKE_DOCKER_LOG:?}"
case "$1 $2" in
  "image inspect")
    if [[ "${3:-}" == "openclaw-sandbox-coder:bookworm-slim" ]]; then
      exit 0
    fi
    ;;
  "image save")
    touch "$4"
    exit 0
    ;;
esac
exit 0
SH
chmod +x "${fake_bin}/docker"

cat >"${fake_bin}/ssh-keyscan" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'ssh-keyscan %s\n' "$*" >>"${FAKE_SSH_KEYSCAN_LOG:?}"
printf '[10.10.0.1]:2222 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeKeyForTestOnly\n'
SH
chmod +x "${fake_bin}/ssh-keyscan"

cat >"${fake_bin}/ssh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'ssh %s\n' "$*" >>"${FAKE_SSH_LOG:?}"
exit 1
SH
chmod +x "${fake_bin}/ssh"

cat >"${fake_bin}/scp" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'scp %s\n' "$*" >>"${FAKE_SCP_LOG:?}"
exit 0
SH
chmod +x "${fake_bin}/scp"

(
  cd "${repo_dir}"
  export PATH="${fake_bin}:$PATH"
  export FAKE_DOCKER_LOG="${sandbox_dir}/docker.log"
  export FAKE_SSH_KEYSCAN_LOG="${sandbox_dir}/ssh-keyscan.log"
  export FAKE_SSH_LOG="${sandbox_dir}/ssh.log"
  export FAKE_SCP_LOG="${sandbox_dir}/scp.log"
  ./scripts/openclaw-remote-docker-load-images.sh \
    --docker-host ssh://docker-remote@10.10.0.1:2222 \
    --identity-file "${sandbox_dir}/id_ed25519" \
    --image openclaw-sandbox-coder:bookworm-slim \
    >"${sandbox_dir}/output.log" 2>&1 || true
)

ssh_keyscan_log="$(cat "${sandbox_dir}/ssh-keyscan.log")"
ssh_log="$(cat "${sandbox_dir}/ssh.log")"

assert_contains "${ssh_keyscan_log}" "-p 2222 10.10.0.1"
assert_contains "${ssh_log}" "UserKnownHostsFile="
assert_contains "${ssh_log}" "GlobalKnownHostsFile=/dev/null"
assert_contains "${ssh_log}" "-i ${sandbox_dir}/id_ed25519"

echo "openclaw remote docker load images tests passed"
