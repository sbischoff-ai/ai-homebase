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

sandbox_dir="$(mktemp -d)"
trap 'rm -rf "${sandbox_dir}"' EXIT

fake_bin="${sandbox_dir}/bin"
repo_dir="${sandbox_dir}/repo"
command_log="${sandbox_dir}/commands.log"
output_file="${sandbox_dir}/output.log"
mkdir -p "${fake_bin}" "${repo_dir}/scripts/lib"

cp "${SCRIPT_PATH}" "${repo_dir}/scripts/test-local-k3d.sh"
cp "${REPO_ROOT}/scripts/lib/logging.sh" "${repo_dir}/scripts/lib/logging.sh"
chmod +x "${repo_dir}/scripts/test-local-k3d.sh"

cat >"${fake_bin}/helm" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
printf 'helm %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
case "$1 $2" in
  "dependency update")
    exit 0
    ;;
  "upgrade --install")
    exit 0
    ;;
  "get values")
    cat <<'JSON'
{"openclaw":{"ingress":{"enabled":true}},"gitea":{"enabled":true}}
JSON
    exit 0
    ;;
esac
printf 'unexpected helm invocation: %s\n' "$*" >&2
exit 1
FAKE
chmod +x "${fake_bin}/helm"

cat >"${fake_bin}/kubectl" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
printf 'kubectl %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
  case "${args[$i]}" in
    get)
      resource_types="${args[$((i+1))]}"
      if [[ "${resource_types}" == "deployment,statefulset" ]]; then
        selector="${args[$((i+3))]}"
        case "${selector}" in
          app.kubernetes.io/instance=test-release,app.kubernetes.io/name=openclaw)
            printf 'Deployment/test-release-openclaw\n'
            exit 0
            ;;
          app.kubernetes.io/instance=test-release,app.kubernetes.io/name=gitea)
            printf 'StatefulSet/test-release-gitea\n'
            exit 0
            ;;
        esac
      elif [[ "${resource_types}" == "service" ]]; then
        selector="${args[$((i+3))]}"
        if [[ "${selector}" == "app.kubernetes.io/instance=test-release,app.kubernetes.io/name=gitea" ]]; then
          printf 'Service/test-release-gitea-http\nService/test-release-gitea-ssh\n'
          exit 0
        fi
      fi
      ;;
    rollout)
      exit 0
      ;;
    wait)
      exit 0
      ;;
  esac
done
printf 'unexpected kubectl invocation: %s\n' "$*" >&2
exit 1
FAKE
chmod +x "${fake_bin}/kubectl"

cat >"${fake_bin}/curl" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
printf 'curl %s\n' "$*" >>"${FAKE_COMMAND_LOG:?}"
exit 0
FAKE
chmod +x "${fake_bin}/curl"

cat >"${fake_bin}/python3" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
exec "${REAL_PYTHON3:?}" "$@"
FAKE
chmod +x "${fake_bin}/python3"

REAL_PYTHON3="$(python3 -c 'import sys; print(sys.executable)')"
(
  cd "${repo_dir}"
  export PATH="${fake_bin}:$PATH"
  export REAL_PYTHON3
  export FAKE_COMMAND_LOG="${command_log}"
  ./scripts/test-local-k3d.sh --release-name test-release --namespace test-namespace --kubeconfig "${sandbox_dir}/kubeconfig.yaml"
) >"${output_file}" 2>&1

output="$(cat "${output_file}")"
commands="$(cat "${command_log}")"

assert_contains "${output}" "Local k3d smoke checks passed for release=test-release namespace=test-namespace"
assert_contains "${commands}" "kubectl --kubeconfig ${sandbox_dir}/kubeconfig.yaml -n test-namespace rollout status StatefulSet/test-release-gitea --timeout=600s"
assert_contains "${commands}" "kubectl --kubeconfig ${sandbox_dir}/kubeconfig.yaml -n test-namespace get service -l app.kubernetes.io/instance=test-release,app.kubernetes.io/name=gitea -o jsonpath={range .items[*]}{.kind}{\"/\"}{.metadata.name}{\"\\n\"}{end}"
assert_contains "${commands}" "curl --silent --show-error --fail -H Host: openclaw.localtest.me http://127.0.0.1/"

echo "local k3d smoke test script tests passed"
