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

assert_not_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "${haystack}" == *"${needle}"* ]]; then
    printf 'expected output to omit: %s\n' "${needle}" >&2
    printf 'actual output:\n%s\n' "${haystack}" >&2
    exit 1
  fi
}

render_profile() {
  local output_file="$1"
  shift
  nix-shell --run "./scripts/template.sh --release-name platform-stack --namespace ai-homebase $* > ${output_file}"
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

k3d_render="${tmpdir}/platform-stack-k3d.yaml"
k3s_render="${tmpdir}/platform-stack-k3s.yaml"

(
  cd "${REPO_ROOT}"
  render_profile "${k3d_render}" "--values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3d.yaml"
  render_profile "${k3s_render}" "--values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3s.yaml"
)

k3d_openclaw="$(awk '
  /# Source: platform-stack\/charts\/openclaw\/templates\/deployment.yaml/ {capture=1}
  capture {print}
  capture && /^---$/ {exit}
' "${k3d_render}")"
k3s_openclaw="$(awk '
  /# Source: platform-stack\/charts\/openclaw\/templates\/deployment.yaml/ {capture=1}
  capture {print}
  capture && /^---$/ {exit}
' "${k3s_render}")"

assert_contains "${k3d_openclaw}" 'hostPath:'
assert_contains "${k3d_openclaw}" 'path: "/var/lib/ai-homebase/openclaw-state"'
assert_not_contains "${k3d_openclaw}" 'claimName: platform-stack-openclaw'

assert_contains "${k3s_openclaw}" 'hostPath:'
assert_contains "${k3s_openclaw}" 'path: "/var/lib/ai-homebase/openclaw-state"'
assert_not_contains "${k3s_openclaw}" 'claimName: platform-stack-openclaw'

echo "openclaw storage render tests passed"
