#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_PATH="${REPO_ROOT}/scripts/test-local-k3d.sh"

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

run_case() {
  local case_name="$1"
  local gitea_enabled="$2"

  local sandbox_dir
  sandbox_dir="$(mktemp -d)"
  trap 'rm -rf "${sandbox_dir}"' RETURN

  local repo_dir="${sandbox_dir}/repo"
  local fake_bin="${sandbox_dir}/bin"
  local helm_log="${sandbox_dir}/helm.log"
  local kubectl_log="${sandbox_dir}/kubectl.log"
  local curl_log="${sandbox_dir}/curl.log"
  local output_file="${sandbox_dir}/output.log"
  mkdir -p "${repo_dir}/scripts/lib" "${fake_bin}"

  cp "${SCRIPT_PATH}" "${repo_dir}/scripts/test-local-k3d.sh"
  cp "${REPO_ROOT}/scripts/lib/logging.sh" "${repo_dir}/scripts/lib/logging.sh"
  chmod +x "${repo_dir}/scripts/test-local-k3d.sh"

  cat >"${fake_bin}/helm" <<'FAKEHELM'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${FAKE_HELM_LOG:?}"
case "$1 $2" in
  "get values")
    cat <<JSON
{"openclaw":{"ingress":{"enabled":true,"hosts":[{"host":"openclaw.test.internal"}]},"remoteDocker":{"enabled":true,"dockerHost":"ssh://docker-remote@host.k3d.internal:2222"}},"nextcloud":{"enabled":false,"ingress":{"private":{"host":"nextcloud.test.internal"}}},"nextcloudMcp":{"enabled":false,"ingress":{"hosts":[{"host":"nextcloud-mcp.test.internal"}]}},"gitea":{"enabled":${FAKE_GITEA_ENABLED:-true},"gitea":{"ingress":{"hosts":[{"host":"gitea.test.internal"}]}}},"registry":{"enabled":false,"ingress":{"hosts":[{"host":"registry.localtest.me"}]}},"vaultwarden":{"enabled":false,"ingress":{"hosts":[{"host":"vaultwarden.test.internal"}]}},"postfixRelay":{"enabled":false},"paperlessNgx":{"enabled":true,"ingress":{"hosts":[{"host":"paperless.test.internal"}]}},"qdrant":{"enabled":false,"ingress":{"hosts":[{"host":"qdrant.test.internal"}]}},"qdrantMcp":{"enabled":false,"ingress":{"hosts":[{"host":"qdrant-mcp.test.internal"}]}},"memgraph":{"enabled":false,"ingress":{"hosts":[{"host":"memgraph.test.internal"}]}},"memgraphLab":{"enabled":false,"ingress":{"hosts":[{"host":"memgraph-lab.test.internal"}]}}}
JSON
    exit 0
    ;;
  "get manifest")
    if [[ "${FAKE_GITEA_ENABLED:-true}" == "true" ]]; then
      cat <<'YAML'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: platform-stack-gitea
---
apiVersion: v1
kind: Service
metadata:
  name: platform-stack-gitea-http
---
apiVersion: v1
kind: Service
metadata:
  name: platform-stack-gitea-ssh
YAML
    fi
    exit 0
    ;;
esac
printf 'unexpected helm invocation: %s\n' "$*" >&2
exit 1
FAKEHELM
  chmod +x "${fake_bin}/helm"

  cat >"${fake_bin}/kubectl" <<'FAKEKUBECTL'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${FAKE_KUBECTL_LOG:?}"
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
  if [[ "${args[$i]}" == "get" && $((i+1)) -lt ${#args[@]} ]]; then
    resource="${args[$((i+1))]}"
    if [[ "${resource}" == "deployment" ]]; then
      printf 'platform-stack-openclaw'
      exit 0
    fi
    if [[ "${resource}" == "secret" && $((i+2)) -lt ${#args[@]} ]]; then
      secret_name="${args[$((i+2))]}"
      case "${secret_name}" in
        reviewer-credentials)
          printf 'cmV2aWV3ZXItdG9rZW4='
          exit 0
          ;;
        gitea-admin-secret)
          if [[ "$*" == *".data.username"* ]]; then
            printf 'Z2l0LWFkbWlu'
          else
            printf 'Z2l0LWFkbWluLXBhc3M='
          fi
          exit 0
          ;;
      esac
    fi
    if [[ "${resource}" == "configmap" ]]; then
      cat <<'JSON'
{"commands":{"mcp":true},"cron":{"enabled":true,"store":"~/.openclaw/cron/jobs.json"},"agents":{"defaults":{"sandbox":{"backend":"docker","docker":{"image":"registry.localtest.me/openclaw/openclaw-sandbox:trixie-slim","env":{"HOME":"/workspace/.home","SSL_CERT_FILE":"/workspace/.openclaw-runtime/ai-homebase-ca-bundle.crt","REQUESTS_CA_BUNDLE":"/workspace/.openclaw-runtime/ai-homebase-ca-bundle.crt","NODE_EXTRA_CA_CERTS":"/workspace/.openclaw-runtime/ai-homebase-ca-bundle.crt","GIT_SSL_CAINFO":"/workspace/.openclaw-runtime/ai-homebase-ca-bundle.crt","CURL_CA_BUNDLE":"/workspace/.openclaw-runtime/ai-homebase-ca-bundle.crt"}}},"list":[{"id":"coder","sandbox":{"docker":{"image":"registry.localtest.me/openclaw/openclaw-sandbox-coder:trixie-slim","env":{"DOCKER_HOST":"${DOCKER_HOST}","CODER_GITEA_TOKEN":"${CODER_GITEA_TOKEN}"}}}},{"id":"architect","sandbox":{"mode":"non-main","docker":{"env":{"REVIEWER_GITEA_BASE_URL":"https://gitea.test.internal","REVIEWER_GITEA_HOST":"gitea.test.internal","REVIEWER_GITEA_TOKEN":"${REVIEWER_GITEA_TOKEN}"}}}},{"id":"auditor","sandbox":{"mode":"off"}}]},"mcp":{"servers":{"nextcloud":{"args":["${OPENCLAW_NEXTCLOUD_MCP_INTERNAL_URL}","${OPENCLAW_NEXTCLOUD_MCP_EXTERNAL_URL}"]}}}}
JSON
      exit 0
    fi
    if [[ "${resource}" == "statefulset/platform-stack-gitea" || "${resource}" == "service/platform-stack-gitea-http" || "${resource}" == "service/platform-stack-gitea-ssh" ]]; then
      exit 0
    fi
    if [[ "${resource}" == "statefulset" ]]; then
      printf 'platform-stack-paperless-ngx'
      exit 0
    fi
    if [[ "${resource}" == "statefulset/platform-stack-paperless-ngx" || "${resource}" == "service/platform-stack-paperless-ngx" ]]; then
      exit 0
    fi
    if [[ "${resource}" == "service" ]]; then
      printf 'platform-stack-paperless-ngx'
      exit 0
    fi
    if [[ "${resource}" == "ingress" || "${resource}" == ingress/* ]]; then
      exit 0
    fi
  fi
  if [[ "${args[$i]}" == "rollout" && $((i+2)) -lt ${#args[@]} && "${args[$((i+1))]}" == "status" ]]; then
    exit 0
  fi
  if [[ "${args[$i]}" == "wait" ]]; then
    exit 0
  fi
  if [[ "${args[$i]}" == "exec" && "$*" == *"openclaw cron list --json"* ]]; then
    cat <<'JSON'
[{"name":"Watchdog platform sweep"},{"name":"Watchdog nightly activity check"},{"name":"Watchdog daily digest"},{"name":"Archivist weekly graph grooming"},{"name":"Auditor weekly review"},{"name":"Watchdog daily wrap-up"},{"name":"Architect daily wrap-up"},{"name":"Archivist daily wrap-up"},{"name":"Auditor daily wrap-up"},{"name":"Main daily wrap-up"}]
JSON
    exit 0
  fi
  if [[ "${args[$i]}" == "exec" ]]; then
    exit 0
  fi
done
printf 'unexpected kubectl invocation: %s\n' "$*" >&2
exit 1
FAKEKUBECTL
  chmod +x "${fake_bin}/kubectl"

  cat >"${fake_bin}/curl" <<'FAKECURL'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${FAKE_CURL_LOG:?}"
counter_file="${FAKE_CURL_COUNTER_FILE:?}"
count=0
if [[ -f "${counter_file}" ]]; then
  count="$(cat "${counter_file}")"
fi
count=$((count + 1))
printf '%s' "${count}" >"${counter_file}"
if [[ "${FAKE_FAIL_FIRST_PAPERLESS_CURL:-0}" == "1" && "$*" == *"Host: paperless.test.internal http://127.0.0.1/api/health/"* && "${count}" -eq 2 ]]; then
  exit 22
fi
exit 0
FAKECURL
  chmod +x "${fake_bin}/curl"

  cat >"${fake_bin}/incus" <<'FAKEINCUS'
#!/usr/bin/env bash
set -euo pipefail
exit 0
FAKEINCUS
  chmod +x "${fake_bin}/incus"

  if ! (
    cd "${repo_dir}"
    export PATH="${fake_bin}:$PATH"
    export FAKE_HELM_LOG="${helm_log}"
    export FAKE_KUBECTL_LOG="${kubectl_log}"
    export FAKE_CURL_LOG="${curl_log}"
    export FAKE_CURL_COUNTER_FILE="${sandbox_dir}/curl-counter"
    export FAKE_GITEA_ENABLED="${gitea_enabled}"
    export FAKE_FAIL_FIRST_PAPERLESS_CURL="1"
    export CODER_GITEA_USERNAME="coder"
    export CODER_GITEA_TOKEN="coder-token"
    export REVIEWER_GITEA_TOKEN="reviewer-token"
    export REVIEWER_GITEA_USERNAME="reviewer"
    export REVIEWER_GITEA_EMAIL="reviewer@example.invalid"
    export GITOPS_REPO_NAME="cluster-gitops"

    ./scripts/test-local-k3d.sh \
      --release-name platform-stack \
      --namespace ai-homebase \
      --kubeconfig "${sandbox_dir}/kubeconfig.yaml" \
      --skip-install
  ) >"${output_file}" 2>&1; then
    cat "${output_file}" >&2
    exit 1
  fi

  local output helm_output kubectl_output curl_output
  output="$(cat "${output_file}")"
  helm_output="$(cat "${helm_log}")"
  kubectl_output="$(cat "${kubectl_log}")"
  curl_output="$(cat "${curl_log}")"

  assert_contains "${output}" "Local k3d smoke checks passed"
  assert_contains "${curl_output}" "-H Host: openclaw.test.internal http://127.0.0.1/"
  assert_contains "${kubectl_output}" "exec deployment/platform-stack-openclaw -- sh -ceu"

  case "${case_name}" in
    gitea-enabled)
      assert_contains "${kubectl_output}" "rollout status statefulset/platform-stack-gitea --timeout=1200s"
      assert_contains "${kubectl_output}" "get service/platform-stack-gitea-http"
      assert_contains "${kubectl_output}" "get service/platform-stack-gitea-ssh"
      ;;
    gitea-disabled)
      assert_contains "${output}" "Skipping Gitea workload/service checks because gitea.enabled=false"
      assert_not_contains "${kubectl_output}" "statefulset/platform-stack-gitea"
      assert_not_contains "${kubectl_output}" "service/platform-stack-gitea-http"
      ;;
    *)
      printf 'unknown case_name: %s\n' "${case_name}" >&2
      exit 1
      ;;
  esac

  trap - RETURN
  rm -rf "${sandbox_dir}"
}

run_case gitea-enabled true
run_case gitea-disabled false

echo "test-local-k3d script tests passed"
