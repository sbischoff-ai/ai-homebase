#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_PATH="${REPO_ROOT}/scripts/bootstrap-secrets.sh"

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
    printf 'did not expect output to contain: %s\n' "${needle}" >&2
    printf 'actual output:\n%s\n' "${haystack}" >&2
    exit 1
  fi
}

run_case() {
  local case_name="$1"
  local ssh_keyscan_mode="$2"
  local key_mode="$3"
  shift 3

  local sandbox_dir
  sandbox_dir="$(mktemp -d)"
  trap 'rm -rf "${sandbox_dir}"' RETURN

  local fake_bin="${sandbox_dir}/bin"
  local key_path="${sandbox_dir}/remote-id_ed25519"
  local bootstrap_config_path="${sandbox_dir}/bootstrap.local.toml"
  local output_file="${sandbox_dir}/output.log"
  local kubectl_log="${sandbox_dir}/kubectl.log"
  mkdir -p "${fake_bin}"

  case "${key_mode}" in
    present) printf 'test-private-key\n' >"${key_path}" ;;
    empty) : >"${key_path}" ;;
    missing) ;;
    *) printf 'unknown key_mode: %s\n' "${key_mode}" >&2; exit 1 ;;
  esac

  cat >"${fake_bin}/kubectl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
log_file="${FAKE_KUBECTL_LOG:?}"
printf '%s\n' "$*" >>"${log_file}"

if [[ "$1" == "--kubeconfig" ]]; then
  shift 2
fi

if [[ "$1" == "-n" ]]; then
  shift 2
fi

case "$1" in
  apply)
    if [[ "$2" == "-f" ]]; then
      manifest_path="$3"
      if grep -q "kind: Namespace" "${manifest_path}"; then
        printf 'namespace/%s configured\n' "${FAKE_NAMESPACE:-ai-homebase}"
      else
        printf 'secret/test configured\n'
      fi
      exit 0
    fi
    ;;
  create)
    if [[ "$2" == "secret" && "$3" == "generic" ]]; then
      shift 4
      printf 'apiVersion: v1\nkind: Secret\nmetadata:\n  name: test\n'
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --from-literal=*) printf 'literal=%s\n' "${1#--from-literal=}" >>"${log_file}" ;;
          --from-file=id_ed25519=*) printf 'validated-id-ed25519=%s\n' "${1#--from-file=id_ed25519=}" >>"${log_file}" ;;
          --from-file=known_hosts=*)
            known_hosts_path="${1#--from-file=known_hosts=}"
            printf 'validated-known-hosts=%s\n' "${known_hosts_path}" >>"${log_file}"
            if [[ ! -s "${known_hosts_path}" ]]; then
              printf 'known_hosts path was empty: %s\n' "${known_hosts_path}" >&2
              exit 1
            fi
            ;;
        esac
        shift
      done
      exit 0
    fi
    ;;
esac

printf 'unexpected kubectl invocation: %s\n' "$*" >&2
exit 1
SH
  chmod +x "${fake_bin}/kubectl"

  cat >"${fake_bin}/openssl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == "rand" && "$2" == "-hex" ]]; then
  bytes="$3"
  case "${bytes}" in
    24) printf '0123456789abcdef0123456789abcdef0123456789abcdef\n' ;;
    32) printf 'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210\n' ;;
    *) printf 'unexpected openssl rand -hex bytes: %s\n' "${bytes}" >&2; exit 1 ;;
  esac
  exit 0
fi
printf 'unexpected openssl invocation: %s\n' "$*" >&2
exit 1
SH
  chmod +x "${fake_bin}/openssl"

  cat >"${fake_bin}/ssh-keyscan" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
mode="${FAKE_SSH_KEYSCAN_MODE:-success}"
if [[ "${mode}" == "success" ]]; then
  printf '[%s]:%s ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKey\n' "$3" "$2"
fi
exit 0
SH
  chmod +x "${fake_bin}/ssh-keyscan"

  local status=0
  (
    export PATH="${fake_bin}:$PATH"
    export FAKE_KUBECTL_LOG="${kubectl_log}"
    export FAKE_NAMESPACE="test-namespace"
    export FAKE_SSH_KEYSCAN_MODE="${ssh_keyscan_mode}"
    export HOME="${sandbox_dir}/home"
    mkdir -p "${HOME}"

    openai_api_key=""
    anthropic_api_key=""
    brave_api_key=""
    gemini_api_key=""
    gitea_db_password=""
    vaultwarden_db_password=""
    vaultwarden_admin_token=""

    while [[ $# -gt 0 ]]; do
      assignment="$1"
      key="${assignment%%=*}"
      value="${assignment#*=}"
      case "${key}" in
        OPENAI_API_KEY) openai_api_key="${value}" ;;
        ANTHROPIC_API_KEY) anthropic_api_key="${value}" ;;
        BRAVE_API_KEY) brave_api_key="${value}" ;;
        GEMINI_API_KEY) gemini_api_key="${value}" ;;
        GITEA_DB_PASSWORD) gitea_db_password="${value}" ;;
        VAULTWARDEN_DB_PASSWORD) vaultwarden_db_password="${value}" ;;
        VAULTWARDEN_ADMIN_TOKEN) vaultwarden_admin_token="${value}" ;;
      esac
      shift
    done

    cat >"${bootstrap_config_path}" <<EOF
[providers]
openai_api_key = "${openai_api_key}"
anthropic_api_key = "${anthropic_api_key}"
brave_api_key = "${brave_api_key}"
perplexity_api_key = ""
gemini_api_key = "${gemini_api_key}"
xai_api_key = ""
moonshot_api_key = ""

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

[admin]
name = "Test Admin"
username = "test-admin"
email = "admin@example.invalid"
password = ""

[secrets]
openclaw_gateway_token = ""
postgres_admin_password = ""
redis_password = ""
gitea_db_password = "${gitea_db_password}"
vaultwarden_db_password = "${vaultwarden_db_password}"
vaultwarden_admin_token = "${vaultwarden_admin_token}"
nextcloud_db_password = ""
paperless_db_password = ""
paperless_secret_key = ""

[services.gitea.admin]
username = "git-admin"
email = "git@example.invalid"
password = ""

[services.nextcloud.admin]
user = "nextcloud-admin"
password = ""

[services.paperless.admin]
user = "paperless-admin"
mail = "paperless@example.invalid"
password = ""
EOF

    "${SCRIPT_PATH}" \
      --profile k3d \
      --bootstrap-config "${bootstrap_config_path}" \
      --namespace test-namespace \
      --remote-docker-secret openclaw-remote-docker-ssh \
      --remote-docker-host remote.example.internal \
      --remote-docker-port 2202 \
      --remote-docker-key "${key_path}"
  ) >"${output_file}" 2>&1 || status=$?

  local output kubectl_output
  output="$(cat "${output_file}")"
  kubectl_output="$(cat "${kubectl_log}" 2>/dev/null || true)"

  case "${case_name}" in
    success-openai)
      [[ ${status} -eq 0 ]] || { printf 'expected success, got status %s\n%s\n' "${status}" "${output}" >&2; exit 1; }
      assert_contains "${output}" "updated secret openclaw-remote-docker-ssh"
      assert_contains "${kubectl_output}" "literal=postgres-password=0123456789abcdef0123456789abcdef0123456789abcdef"
      assert_contains "${kubectl_output}" "literal=redis-password=0123456789abcdef0123456789abcdef0123456789abcdef"
      assert_contains "${kubectl_output}" "literal=OPENCLAW_GATEWAY_TOKEN=0123456789abcdef0123456789abcdef0123456789abcdef"
      assert_contains "${kubectl_output}" "literal=OPENAI_API_KEY=test-openai-key"
      assert_contains "${kubectl_output}" "literal=GITEA__database__PASSWD=0123456789abcdef0123456789abcdef0123456789abcdef"
      assert_contains "${kubectl_output}" "literal=username=git-admin"
      assert_contains "${kubectl_output}" "literal=email=git@example.invalid"
      assert_contains "${kubectl_output}" "literal=password=0123456789abcdef0123456789abcdef0123456789abcdef"
      assert_contains "${kubectl_output}" "literal=VAULTWARDEN_DB_PASSWORD=0123456789abcdef0123456789abcdef0123456789abcdef"
      assert_contains "${kubectl_output}" "literal=ADMIN_TOKEN=0123456789abcdef0123456789abcdef0123456789abcdef"
      assert_contains "${kubectl_output}" "literal=NEXTCLOUD_USERNAME=openclaw"
      assert_contains "${kubectl_output}" "literal=NEXTCLOUD_PASSWORD=0123456789abcdef0123456789abcdef0123456789abcdef"
      assert_contains "${kubectl_output}" "literal=OPENCLAW_NEXTCLOUD_MCP_AUTH_HEADER=Basic b3BlbmNsYXc6MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWYwMTIzNDU2Nzg5YWJjZGVm"
      assert_contains "${kubectl_output}" "literal=PAPERLESS_SECRET_KEY=fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"
      assert_contains "${kubectl_output}" "validated-id-ed25519=${key_path}"
      assert_contains "${kubectl_output}" "validated-known-hosts="
      assert_not_contains "${kubectl_output}" "get secret "
      ;;
    success-multiple)
      [[ ${status} -eq 0 ]] || { printf 'expected success, got status %s\n%s\n' "${status}" "${output}" >&2; exit 1; }
      assert_contains "${kubectl_output}" "literal=OPENAI_API_KEY=test-openai-key"
      assert_contains "${kubectl_output}" "literal=BRAVE_API_KEY=test-brave-key"
      assert_contains "${kubectl_output}" "literal=GEMINI_API_KEY=test-gemini-key"
      ;;
    success-explicit-gitea-password)
      [[ ${status} -eq 0 ]] || { printf 'expected success, got status %s\n%s\n' "${status}" "${output}" >&2; exit 1; }
      assert_contains "${kubectl_output}" "literal=GITEA__database__PASSWD=explicit-gitea-password"
      ;;
    success-explicit-vaultwarden-password)
      [[ ${status} -eq 0 ]] || { printf 'expected success, got status %s\n%s\n' "${status}" "${output}" >&2; exit 1; }
      assert_contains "${kubectl_output}" "literal=VAULTWARDEN_DB_PASSWORD=explicit-vaultwarden-password"
      ;;
    success-explicit-vaultwarden-admin-token)
      [[ ${status} -eq 0 ]] || { printf 'expected success, got status %s\n%s\n' "${status}" "${output}" >&2; exit 1; }
      assert_contains "${kubectl_output}" "literal=ADMIN_TOKEN=explicit-vaultwarden-admin-token"
      ;;
    missing-provider)
      [[ ${status} -ne 0 ]] || { printf 'expected failure without provider/search key\n%s\n' "${output}" >&2; exit 1; }
      assert_contains "${output}" "At least one supported OpenClaw provider/search key is required in [providers]."
      ;;
    missing-key)
      [[ ${status} -ne 0 ]] || { printf 'expected failure for missing/empty key\n%s\n' "${output}" >&2; exit 1; }
      assert_contains "${output}" "Remote Docker private key missing or empty at ${key_path}."
      assert_contains "${output}" "Secret openclaw-remote-docker-ssh must provide non-empty id_ed25519 and known_hosts keys."
      assert_contains "${output}" "OpenClaw init will fail if those keys are absent."
      ;;
    empty-known-hosts)
      [[ ${status} -ne 0 ]] || { printf 'expected failure for empty known_hosts\n%s\n' "${output}" >&2; exit 1; }
      assert_contains "${output}" "ssh-keyscan did not write known_hosts data for remote.example.internal:2202."
      assert_contains "${output}" "Secret openclaw-remote-docker-ssh must provide non-empty id_ed25519 and known_hosts keys."
      assert_contains "${output}" "OpenClaw init will fail if those keys are absent."
      ;;
    *) printf 'unknown case_name: %s\n' "${case_name}" >&2; exit 1 ;;
  esac

  trap - RETURN
  rm -rf "${sandbox_dir}"
}

run_case success-openai success present OPENAI_API_KEY=test-openai-key ANTHROPIC_API_KEY=test-anthropic-key
run_case success-multiple success present OPENAI_API_KEY=test-openai-key ANTHROPIC_API_KEY=test-anthropic-key BRAVE_API_KEY=test-brave-key GEMINI_API_KEY=test-gemini-key
run_case success-explicit-gitea-password success present OPENAI_API_KEY=test-openai-key ANTHROPIC_API_KEY=test-anthropic-key GITEA_DB_PASSWORD=explicit-gitea-password
run_case success-explicit-vaultwarden-password success present OPENAI_API_KEY=test-openai-key ANTHROPIC_API_KEY=test-anthropic-key VAULTWARDEN_DB_PASSWORD=explicit-vaultwarden-password
run_case success-explicit-vaultwarden-admin-token success present OPENAI_API_KEY=test-openai-key ANTHROPIC_API_KEY=test-anthropic-key VAULTWARDEN_ADMIN_TOKEN=explicit-vaultwarden-admin-token
run_case missing-provider success present
run_case missing-key success empty OPENAI_API_KEY=test-openai-key ANTHROPIC_API_KEY=test-anthropic-key
run_case empty-known-hosts empty present OPENAI_API_KEY=test-openai-key ANTHROPIC_API_KEY=test-anthropic-key

echo "k3d bootstrap secrets tests passed"
