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

fake_bin="${sandbox_dir}/bin"
repo_dir="${sandbox_dir}/repo"
helm_log="${sandbox_dir}/helm.log"
kubectl_log="${sandbox_dir}/kubectl.log"
output_log="${sandbox_dir}/output.log"
mkdir -p "${fake_bin}" "${repo_dir}/scripts"
cp "${REPO_ROOT}/scripts/bootstrap-apply.sh" "${repo_dir}/scripts/bootstrap-apply.sh"
chmod +x "${repo_dir}/scripts/bootstrap-apply.sh"

cat >"${fake_bin}/helm" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'helm %s\n' "$*" >>"${FAKE_HELM_LOG:?}"
case "$*" in
  "dependency update charts/argo-cd"|"dependency update charts/gitea"|"dependency update charts/platform-stack")
    exit 0
    ;;
  template*)
    printf 'kind: ConfigMap\nmetadata:\n  name: no-cert-manager-here\n'
    exit 0
    ;;
  upgrade\ --install*)
    exit 0
    ;;
esac
printf 'unexpected helm invocation: %s\n' "$*" >&2
exit 1
SH
chmod +x "${fake_bin}/helm"

cat >"${fake_bin}/kubectl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'kubectl %s\n' "$*" >>"${FAKE_KUBECTL_LOG:?}"
case "$*" in
  *"get secret platform-stack-root-ca"*)
    exit 1
    ;;
esac
exit 0
SH
chmod +x "${fake_bin}/kubectl"

set +e
(
  cd "${repo_dir}"
  PATH="${fake_bin}:${PATH}" \
  HOME="${sandbox_dir}/home" \
  FAKE_HELM_LOG="${helm_log}" \
  FAKE_KUBECTL_LOG="${kubectl_log}" \
  BOOTSTRAP_APPLY_INSTALL_ONLY=1 \
  ./scripts/bootstrap-apply.sh \
    --profile k3s \
    --bootstrap-config "" \
    --shared-openclaw-state-source "${sandbox_dir}/openclaw-state" \
    --internal-skip-gitops \
    >"${output_log}" 2>&1
)
status=$?
set -e

if [[ "${status}" -ne 0 ]]; then
  cat "${output_log}" >&2
  cat "${helm_log}" >&2 || true
  cat "${kubectl_log}" >&2 || true
  exit "${status}"
fi

helm_output="$(cat "${helm_log}")"

expected_sequence=$'helm dependency update charts/argo-cd\nhelm dependency update charts/gitea\nhelm dependency update charts/platform-stack'
actual_sequence="$(printf '%s\n' "${helm_output}" | sed -n '1,3p')"
if [[ "${actual_sequence}" != "${expected_sequence}" ]]; then
  printf 'expected wrapper dependencies before umbrella dependency update\n' >&2
  printf 'expected:\n%s\nactual:\n%s\n' "${expected_sequence}" "${actual_sequence}" >&2
  exit 1
fi

assert_contains "${helm_output}" "helm upgrade --install platform-stack charts/platform-stack"

echo "bootstrap apply dependency tests passed"
