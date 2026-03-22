#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_PATH="${REPO_ROOT}/scripts/k3d-bootstrap-secrets.sh"

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
  local existing_gitea_db_password_mode="$4"
  shift 4

  local sandbox_dir
  sandbox_dir="$(mktemp -d)"
  trap 'rm -rf "${sandbox_dir}"' RETURN

  local fake_bin="${sandbox_dir}/bin"
  local key_path="${sandbox_dir}/remote-id_ed25519"
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
    case "${existing_gitea_db_password_mode}" in
      none) unset FAKE_EXISTING_GITEA_DB_PASSWORD_B64 ;;
      existing) export FAKE_EXISTING_GITEA_DB_PASSWORD_B64="ZXhpc3RpbmctZ2l0ZWEtcGFzc3dvcmQ=" ;;
      *) printf 'unknown existing_gitea_db_password_mode: %s\n' "${existing_gitea_db_password_mode}" >&2; exit 1 ;;
    esac
    export INFISICAL_AUTH_SECRET="test-auth-secret"
    export INFISICAL_ENCRYPTION_KEY="test-encryption-key-32-chars-1234"
    export HOME="${sandbox_dir}/home"
    mkdir -p "${HOME}"

    while [[ $# -gt 0 ]]; do
      export "$1"
      shift
    done

    "${SCRIPT_PATH}" \
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
      assert_contains "${kubectl_output}" "literal=OPENCLAW_GATEWAY_TOKEN=local-dev-token"
      assert_contains "${kubectl_output}" "literal=OPENAI_API_KEY=test-openai-key"
      assert_contains "${kubectl_output}" "literal=GITEA__database__PASSWD=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
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
    success-explicit-gitea-password)
      [[ ${status} -eq 0 ]] || { printf 'expected success, got status %s\n%s\n' "${status}" "${output}" >&2; exit 1; }
      assert_contains "${kubectl_output}" "literal=GITEA__database__PASSWD=explicit-gitea-password"
      if [[ "${kubectl_output}" == *"get secret gitea-config-secrets -o jsonpath={.data.GITEA__database__PASSWD}"* ]]; then
        printf 'did not expect bootstrap to read the existing gitea secret when an explicit password was provided\n%s\n' "${kubectl_output}" >&2
        exit 1
      fi
      ;;
    missing-provider)
      [[ ${status} -ne 0 ]] || { printf 'expected failure without provider/search key\n%s\n' "${output}" >&2; exit 1; }
      assert_contains "${output}" "At least one supported OpenClaw provider/search key is required."
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

run_case success-openai success present none OPENAI_API_KEY=test-openai-key
run_case success-anthropic success present none ANTHROPIC_API_KEY=test-anthropic-key
run_case success-multiple success present none OPENAI_API_KEY=test-openai-key BRAVE_API_KEY=test-brave-key GEMINI_API_KEY=test-gemini-key
run_case success-existing-gitea-password success present existing OPENAI_API_KEY=test-openai-key
run_case success-explicit-gitea-password success present none OPENAI_API_KEY=test-openai-key GITEA_DB_PASSWORD=explicit-gitea-password
run_case missing-provider success present none
run_case missing-key success empty none OPENAI_API_KEY=test-openai-key
run_case empty-known-hosts empty present none OPENAI_API_KEY=test-openai-key

echo "k3d bootstrap secrets tests passed"
