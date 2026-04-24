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

line_number_of() {
  local file_path="$1"
  local needle="$2"
  awk -v pat="$needle" 'index($0, pat) { print NR; exit }' "$file_path"
}

sandbox_dir="$(mktemp -d)"
trap 'rm -rf "${sandbox_dir}"' EXIT

repo_dir="${sandbox_dir}/repo"
runtime_root="${sandbox_dir}/runtime-root"
mkdir -p "${repo_dir}/scripts/cron-messages" "${sandbox_dir}/bin" "${runtime_root}/devices"
cp "${REPO_ROOT}/scripts/bootstrap-openclaw-cron.sh" "${repo_dir}/scripts/bootstrap-openclaw-cron.sh"
cp "${REPO_ROOT}"/scripts/cron-messages/*.md "${repo_dir}/scripts/cron-messages/"
chmod +x "${repo_dir}/scripts/bootstrap-openclaw-cron.sh"

cat >"${runtime_root}/devices/pending.json" <<'JSON'
{
  "req-123": {
    "requestId": "req-123",
    "clientId": "cli",
    "clientMode": "cli",
    "role": "operator"
  }
}
JSON

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
        __ETC_BASHLOGOUT_SOURCED=1 \
          OPENCLAW_STATE_DIR="${FAKE_OPENCLAW_STATE_DIR:?}" \
          FAKE_OPENCLAW_LOG="${FAKE_OPENCLAW_LOG:?}" \
          PATH="${FAKE_BIN_DIR:?}:${PATH}" \
          "${args[@]:$((i + 1))}"
        exit $?
      fi
    done
    ;;
esac
printf 'unexpected kubectl invocation: %s\n' "$*" >&2
exit 1
SH
chmod +x "${sandbox_dir}/bin/kubectl"

cat >"${sandbox_dir}/bin/openclaw" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'openclaw %s\n' "$*" >>"${FAKE_OPENCLAW_LOG:?}"
pending_file="${OPENCLAW_STATE_DIR:?}/devices/pending.json"
case "${1:-} ${2:-}" in
  "devices approve")
    printf '{}\n' >"${pending_file}"
    exit 0
    ;;
  "cron list")
    if [[ -s "${pending_file}" ]] && [[ "$(tr -d '[:space:]' <"${pending_file}")" != "{}" ]]; then
      cat >&2 <<'EOF'
gateway connect failed: GatewayClientRequestError: scope upgrade pending approval (requestId: req-123)
Error: gateway closed (1008): pairing required: device is asking for more scopes than currently approved (requestId: req-123)
EOF
      exit 1
    fi
    cat <<'EOF'
Config (/home/node/.openclaw/openclaw.json): missing env var "CODER_GITEA_TOKEN" at agents.list[1].sandbox.docker.env.CODER_GITEA_TOKEN
OpenClaw bootstrap note: cron list succeeded
[]
command completed
EOF
    exit 0
    ;;
  "cron add")
    exit 0
    ;;
esac
printf 'unexpected openclaw invocation: %s\n' "$*" >&2
exit 1
SH
chmod +x "${sandbox_dir}/bin/openclaw"

cat >"${sandbox_dir}/bin/python3" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "-c" ]]; then
  script="${2:-}"
  if [[ "${script}" == *"decoder.raw_decode"* ]]; then
    input="$(cat)"
    if [[ "${input}" == *"[]"* ]]; then
      printf '[]\n'
      exit 0
    fi
    case "${input}" in
      *'['*)
        payload="${input#*[}"
        printf '[%s' "${payload%%]*}]"
        exit 0
        ;;
      *'{'*)
        payload="${input#*\{}"
        printf '{%s' "${payload%%\}*}}"
        exit 0
        ;;
    esac
    printf 'failed to locate JSON payload in command output\n' >&2
    exit 1
  fi
fi

if [[ "${1:-}" == "-" && $# -eq 1 ]]; then
  if [[ -s "${PENDING_FILE:-}" ]] && [[ "$(tr -d '[:space:]' <"${PENDING_FILE}")" != "{}" ]]; then
    printf 'req-123\n'
  fi
  cat >/dev/null
  exit 0
fi

if [[ "${1:-}" == "-" && $# -eq 2 ]]; then
  target="${2:-}"
  if [[ "${OPENCLAW_CRON_JOBS_JSON:-}" == *"\"name\": \"${target}\""* ]] || [[ "${OPENCLAW_CRON_JOBS_JSON:-}" == *"\"name\":\"${target}\""* ]]; then
    exit 0
  fi
  exit 1
fi

printf 'unexpected python3 invocation: %s\n' "$*" >&2
exit 1
SH
chmod +x "${sandbox_dir}/bin/python3"

(
  cd "${repo_dir}"
  export PATH="${sandbox_dir}/bin:${PATH}"
  export FAKE_KUBECTL_LOG="${sandbox_dir}/kubectl.log"
  export FAKE_OPENCLAW_LOG="${sandbox_dir}/openclaw.log"
  export FAKE_OPENCLAW_STATE_DIR="${runtime_root}"
  export FAKE_BIN_DIR="${sandbox_dir}/bin"
  ./scripts/bootstrap-openclaw-cron.sh --release-name platform-stack --namespace ai-homebase >"${sandbox_dir}/output.log"
)

output="$(cat "${sandbox_dir}/output.log")"
openclaw_log="${sandbox_dir}/openclaw.log"
pending_after="$(tr -d '[:space:]' <"${runtime_root}/devices/pending.json")"
approve_line="$(line_number_of "${openclaw_log}" "openclaw devices approve req-123")"
first_list_line="$(line_number_of "${openclaw_log}" "openclaw cron list --json")"

assert_contains "${output}" "Approving OpenClaw bootstrap device request: req-123"
assert_contains "${output}" "Creating OpenClaw cron job: Watchdog platform sweep"
assert_contains "${pending_after}" "{}"

if [[ -z "${approve_line}" || -z "${first_list_line}" || "${approve_line}" -ge "${first_list_line}" ]]; then
  printf 'expected approval to happen before cron list\n' >&2
  printf 'openclaw log:\n' >&2
  cat "${openclaw_log}" >&2
  exit 1
fi

echo "bootstrap OpenClaw cron tests passed"
