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

run_case() {
  local case_name="$1"
  local ssh_keyscan_mode="$2"
  local key_mode="$3"
  local existing_postgres_admin_password_mode="$4"
  local existing_redis_password_mode="$5"
  local existing_gitea_db_password_mode="$6"
  local existing_vaultwarden_db_password_mode="$7"
  local existing_vaultwarden_admin_token_mode="$8"
  shift 8

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
  get)
    if [[ "$2" == "secret" && "$3" == "gitea-config-secrets" ]]; then
      if [[ "${FAKE_EXISTING_GITEA_DB_PASSWORD_B64:-}" != "" ]]; then
        printf '%s' "${FAKE_EXISTING_GITEA_DB_PASSWORD_B64}"
      fi
      exit 0
    fi
    if [[ "$2" == "secret" && "$3" == "shared-postgresql-auth" ]]; then
      if [[ "${FAKE_EXISTING_POSTGRES_ADMIN_PASSWORD_B64:-}" != "" ]]; then
        printf '%s' "${FAKE_EXISTING_POSTGRES_ADMIN_PASSWORD_B64}"
      fi
      exit 0
    fi
    if [[ "$2" == "secret" && "$3" == "shared-redis-auth" ]]; then
      if [[ "${FAKE_EXISTING_REDIS_PASSWORD_B64:-}" != "" ]]; then
        printf '%s' "${FAKE_EXISTING_REDIS_PASSWORD_B64}"
      fi
      exit 0
    fi
    if [[ "$2" == "secret" && "$3" == "vaultwarden-config-secrets" ]]; then
      if [[ "$5" == "jsonpath={.data.VAULTWARDEN_DB_PASSWORD}" ]]; then
        if [[ "${FAKE_EXISTING_VAULTWARDEN_DB_PASSWORD_B64:-}" != "" ]]; then
          printf '%s' "${FAKE_EXISTING_VAULTWARDEN_DB_PASSWORD_B64}"
        fi
      elif [[ "$5" == "jsonpath={.data.ADMIN_TOKEN}" ]]; then
        if [[ "${FAKE_EXISTING_VAULTWARDEN_ADMIN_TOKEN_B64:-}" != "" ]]; then
          printf '%s' "${FAKE_EXISTING_VAULTWARDEN_ADMIN_TOKEN_B64}"
        fi
      fi
      exit 0
    fi
    if [[ "$2" == "secret" && "$3" == "gitea-admin-secret" ]]; then
      if [[ "${FAKE_EXISTING_GITEA_ADMIN_PASSWORD_B64:-}" != "" ]]; then
        printf '%s' "${FAKE_EXISTING_GITEA_ADMIN_PASSWORD_B64}"
      fi
      exit 0
    fi
    if [[ "$2" == "secret" && "$3" == "nextcloud-config-secrets" ]]; then
      case "${4:-}" in
        -o)
          if [[ "$5" == "jsonpath={.data.POSTGRES_PASSWORD}" ]]; then
            printf '%s' "${FAKE_EXISTING_NEXTCLOUD_DB_PASSWORD_B64:-}"
          elif [[ "$5" == "jsonpath={.data.NEXTCLOUD_ADMIN_PASSWORD}" ]]; then
            printf '%s' "${FAKE_EXISTING_NEXTCLOUD_ADMIN_PASSWORD_B64:-}"
          fi
          exit 0
          ;;
      esac
    fi
    if [[ "$2" == "secret" && "$3" == "openclaw-nextcloud-mcp-secrets" ]]; then
      case "${4:-}" in
        -o)
          if [[ "$5" == "jsonpath={.data.NEXTCLOUD_PASSWORD}" ]]; then
            printf '%s' "${FAKE_EXISTING_OPENCLAW_NEXTCLOUD_MCP_PASSWORD_B64:-}"
          fi
          exit 0
          ;;
      esac
    fi
    if [[ "$2" == "secret" && "$3" == "paperless-config-secrets" ]]; then
      case "${4:-}" in
        -o)
          if [[ "$5" == "jsonpath={.data.PAPERLESS_DB_PASSWORD}" ]]; then
            printf '%s' "${FAKE_EXISTING_PAPERLESS_DB_PASSWORD_B64:-}"
          elif [[ "$5" == "jsonpath={.data.PAPERLESS_ADMIN_PASSWORD}" ]]; then
            printf '%s' "${FAKE_EXISTING_PAPERLESS_ADMIN_PASSWORD_B64:-}"
          elif [[ "$5" == "jsonpath={.data.PAPERLESS_SECRET_KEY}" ]]; then
            printf '%s' "${FAKE_EXISTING_PAPERLESS_SECRET_KEY_B64:-}"
          fi
          exit 0
          ;;
      esac
    fi
    ;;
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
if [[ "$1" == "rand" && "$2" == "-base64" ]]; then
  printf 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef0123456789\n'
  exit 0
fi
if [[ "$1" == "rand" && "$2" == "-hex" ]]; then
  printf '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\n'
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
    case "${existing_postgres_admin_password_mode}" in
      none) unset FAKE_EXISTING_POSTGRES_ADMIN_PASSWORD_B64 ;;
      existing) export FAKE_EXISTING_POSTGRES_ADMIN_PASSWORD_B64="ZXhpc3RpbmctcG9zdGdyZXMtYWRtaW4tcGFzc3dvcmQ=" ;;
      *) printf 'unknown existing_postgres_admin_password_mode: %s\n' "${existing_postgres_admin_password_mode}" >&2; exit 1 ;;
    esac
    case "${existing_redis_password_mode}" in
      none) unset FAKE_EXISTING_REDIS_PASSWORD_B64 ;;
      existing) export FAKE_EXISTING_REDIS_PASSWORD_B64="ZXhpc3RpbmctcmVkaXMtcGFzc3dvcmQ=" ;;
      *) printf 'unknown existing_redis_password_mode: %s\n' "${existing_redis_password_mode}" >&2; exit 1 ;;
    esac
    case "${existing_gitea_db_password_mode}" in
      none) unset FAKE_EXISTING_GITEA_DB_PASSWORD_B64 ;;
      existing) export FAKE_EXISTING_GITEA_DB_PASSWORD_B64="ZXhpc3RpbmctZ2l0ZWEtcGFzc3dvcmQ=" ;;
      *) printf 'unknown existing_gitea_db_password_mode: %s\n' "${existing_gitea_db_password_mode}" >&2; exit 1 ;;
    esac
    case "${existing_vaultwarden_db_password_mode}" in
      none) unset FAKE_EXISTING_VAULTWARDEN_DB_PASSWORD_B64 ;;
      existing) export FAKE_EXISTING_VAULTWARDEN_DB_PASSWORD_B64="ZXhpc3RpbmctdmF1bHR3YXJkZW4tcGFzc3dvcmQ=" ;;
      *) printf 'unknown existing_vaultwarden_db_password_mode: %s\n' "${existing_vaultwarden_db_password_mode}" >&2; exit 1 ;;
    esac
    case "${existing_vaultwarden_admin_token_mode}" in
      none) unset FAKE_EXISTING_VAULTWARDEN_ADMIN_TOKEN_B64 ;;
      existing) export FAKE_EXISTING_VAULTWARDEN_ADMIN_TOKEN_B64="ZXhpc3RpbmctdmF1bHR3YXJkZW4tYWRtaW4tdG9rZW4=" ;;
      *) printf 'unknown existing_vaultwarden_admin_token_mode: %s\n' "${existing_vaultwarden_admin_token_mode}" >&2; exit 1 ;;
    esac
    export FAKE_EXISTING_GITEA_ADMIN_PASSWORD_B64="ZXhpc3RpbmctZ2l0ZWEtYWRtaW4tcGFzc3dvcmQ="
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
      assert_contains "${kubectl_output}" "literal=postgres-password=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
      assert_contains "${kubectl_output}" "literal=redis-password=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
      assert_contains "${kubectl_output}" "literal=OPENCLAW_GATEWAY_TOKEN=local-dev-token"
      assert_contains "${kubectl_output}" "literal=OPENAI_API_KEY=test-openai-key"
      assert_contains "${kubectl_output}" "literal=GITEA__database__PASSWD=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
      assert_contains "${kubectl_output}" "literal=username=git-admin"
      assert_contains "${kubectl_output}" "literal=email=git@example.invalid"
      assert_contains "${kubectl_output}" "literal=password=existing-gitea-admin-password"
      assert_contains "${kubectl_output}" "literal=VAULTWARDEN_DB_PASSWORD=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
      assert_contains "${kubectl_output}" "get secret openclaw-nextcloud-mcp-secrets -o jsonpath={.data.NEXTCLOUD_PASSWORD}"
      assert_contains "${kubectl_output}" "literal=NEXTCLOUD_USERNAME=openclaw"
      assert_contains "${kubectl_output}" "literal=NEXTCLOUD_PASSWORD=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
      assert_contains "${kubectl_output}" "literal=OPENCLAW_NEXTCLOUD_MCP_AUTH_HEADER=Basic b3BlbmNsYXc6MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWYwMTIzNDU2Nzg5YWJjZGVmMDEyMzQ1Njc4OWFiY2RlZg=="
      assert_contains "${kubectl_output}" "validated-id-ed25519=${key_path}"
      assert_contains "${kubectl_output}" "validated-known-hosts="
      ;;
    success-anthropic)
      [[ ${status} -eq 0 ]] || { printf 'expected success, got status %s\n%s\n' "${status}" "${output}" >&2; exit 1; }
      assert_contains "${kubectl_output}" "literal=ANTHROPIC_API_KEY=test-anthropic-key"
      ;;
    success-multiple)
      [[ ${status} -eq 0 ]] || { printf 'expected success, got status %s\n%s\n' "${status}" "${output}" >&2; exit 1; }
      assert_contains "${kubectl_output}" "literal=OPENAI_API_KEY=test-openai-key"
      assert_contains "${kubectl_output}" "literal=BRAVE_API_KEY=test-brave-key"
      assert_contains "${kubectl_output}" "literal=GEMINI_API_KEY=test-gemini-key"
      ;;
    success-existing-gitea-password)
      [[ ${status} -eq 0 ]] || { printf 'expected success, got status %s\n%s\n' "${status}" "${output}" >&2; exit 1; }
      assert_contains "${kubectl_output}" "get secret gitea-config-secrets -o jsonpath={.data.GITEA__database__PASSWD}"
      assert_contains "${kubectl_output}" "literal=GITEA__database__PASSWD=existing-gitea-password"
      ;;
    success-existing-shared-passwords)
      [[ ${status} -eq 0 ]] || { printf 'expected success, got status %s\n%s\n' "${status}" "${output}" >&2; exit 1; }
      assert_contains "${kubectl_output}" "get secret shared-postgresql-auth -o jsonpath={.data.postgres-password}"
      assert_contains "${kubectl_output}" "get secret shared-redis-auth -o jsonpath={.data.redis-password}"
      assert_contains "${kubectl_output}" "literal=postgres-password=existing-postgres-admin-password"
      assert_contains "${kubectl_output}" "literal=redis-password=existing-redis-password"
      ;;
    success-explicit-gitea-password)
      [[ ${status} -eq 0 ]] || { printf 'expected success, got status %s\n%s\n' "${status}" "${output}" >&2; exit 1; }
      assert_contains "${kubectl_output}" "literal=GITEA__database__PASSWD=explicit-gitea-password"
      if [[ "${kubectl_output}" == *"get secret gitea-config-secrets -o jsonpath={.data.GITEA__database__PASSWD}"* ]]; then
        printf 'did not expect bootstrap to read the existing gitea secret when an explicit password was provided\n%s\n' "${kubectl_output}" >&2
        exit 1
      fi
      ;;
    success-existing-vaultwarden-password)
      [[ ${status} -eq 0 ]] || { printf 'expected success, got status %s\n%s\n' "${status}" "${output}" >&2; exit 1; }
      assert_contains "${kubectl_output}" "get secret vaultwarden-config-secrets -o jsonpath={.data.VAULTWARDEN_DB_PASSWORD}"
      assert_contains "${kubectl_output}" "literal=VAULTWARDEN_DB_PASSWORD=existing-vaultwarden-password"
      ;;
    success-explicit-vaultwarden-password)
      [[ ${status} -eq 0 ]] || { printf 'expected success, got status %s\n%s\n' "${status}" "${output}" >&2; exit 1; }
      assert_contains "${kubectl_output}" "literal=VAULTWARDEN_DB_PASSWORD=explicit-vaultwarden-password"
      if [[ "${kubectl_output}" == *"get secret vaultwarden-config-secrets -o jsonpath={.data.VAULTWARDEN_DB_PASSWORD}"* ]]; then
        printf 'did not expect bootstrap to read the existing vaultwarden secret when an explicit password was provided\n%s\n' "${kubectl_output}" >&2
        exit 1
      fi
      ;;
    success-existing-vaultwarden-admin-token)
      [[ ${status} -eq 0 ]] || { printf 'expected success, got status %s\n%s\n' "${status}" "${output}" >&2; exit 1; }
      assert_contains "${kubectl_output}" "get secret vaultwarden-config-secrets -o jsonpath={.data.ADMIN_TOKEN}"
      assert_contains "${kubectl_output}" "literal=ADMIN_TOKEN=existing-vaultwarden-admin-token"
      ;;
    success-explicit-vaultwarden-admin-token)
      [[ ${status} -eq 0 ]] || { printf 'expected success, got status %s\n%s\n' "${status}" "${output}" >&2; exit 1; }
      assert_contains "${kubectl_output}" "literal=ADMIN_TOKEN=explicit-vaultwarden-admin-token"
      if [[ "${kubectl_output}" == *"get secret vaultwarden-config-secrets -o jsonpath={.data.ADMIN_TOKEN}"* ]]; then
        printf 'did not expect bootstrap to read the existing vaultwarden admin token when an explicit token was provided\n%s\n' "${kubectl_output}" >&2
        exit 1
      fi
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

run_case success-openai success present none none none none none OPENAI_API_KEY=test-openai-key ANTHROPIC_API_KEY=test-anthropic-key
run_case success-anthropic success present none none none none none OPENAI_API_KEY=test-openai-key ANTHROPIC_API_KEY=test-anthropic-key
run_case success-multiple success present none none none none none OPENAI_API_KEY=test-openai-key ANTHROPIC_API_KEY=test-anthropic-key BRAVE_API_KEY=test-brave-key GEMINI_API_KEY=test-gemini-key
run_case success-existing-shared-passwords success present existing existing none none none OPENAI_API_KEY=test-openai-key ANTHROPIC_API_KEY=test-anthropic-key
run_case success-existing-gitea-password success present none none existing none none OPENAI_API_KEY=test-openai-key ANTHROPIC_API_KEY=test-anthropic-key
run_case success-explicit-gitea-password success present none none none none none OPENAI_API_KEY=test-openai-key ANTHROPIC_API_KEY=test-anthropic-key GITEA_DB_PASSWORD=explicit-gitea-password
run_case success-existing-vaultwarden-password success present none none none existing none OPENAI_API_KEY=test-openai-key ANTHROPIC_API_KEY=test-anthropic-key
run_case success-explicit-vaultwarden-password success present none none none none none OPENAI_API_KEY=test-openai-key ANTHROPIC_API_KEY=test-anthropic-key VAULTWARDEN_DB_PASSWORD=explicit-vaultwarden-password
run_case success-existing-vaultwarden-admin-token success present none none none none existing OPENAI_API_KEY=test-openai-key ANTHROPIC_API_KEY=test-anthropic-key
run_case success-explicit-vaultwarden-admin-token success present none none none none none OPENAI_API_KEY=test-openai-key ANTHROPIC_API_KEY=test-anthropic-key VAULTWARDEN_ADMIN_TOKEN=explicit-vaultwarden-admin-token
run_case missing-provider success present none none none none none
run_case missing-key success empty none none none none none OPENAI_API_KEY=test-openai-key ANTHROPIC_API_KEY=test-anthropic-key
run_case empty-known-hosts empty present none none none none none OPENAI_API_KEY=test-openai-key ANTHROPIC_API_KEY=test-anthropic-key

echo "k3d bootstrap secrets tests passed"
