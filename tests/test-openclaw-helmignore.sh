#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

assert_not_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "${haystack}" == *"${needle}"* ]]; then
    printf 'expected output to omit: %s\n' "${needle}" >&2
    printf 'actual output:\n%s\n' "${haystack}" >&2
    exit 1
  fi
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

chart_dir="${tmpdir}/openclaw"
rendered="${tmpdir}/openclaw.yaml"

cp -a "${REPO_ROOT}/charts/openclaw" "${chart_dir}"

pycache_dir="${chart_dir}/files/workspaces/archivist/qdrant/__pycache__"
mkdir -p "${pycache_dir}"
printf '\363\r\r\n\003\000\000\000invalid-pyc' >"${pycache_dir}/bad.cpython-313.pyc"

helm template test-openclaw "${chart_dir}" --namespace ai-homebase >"${rendered}"

rendered_yaml="$(cat "${rendered}")"
assert_not_contains "${rendered_yaml}" "__pycache__"
assert_not_contains "${rendered_yaml}" ".pyc"
assert_not_contains "${rendered_yaml}" "bad.cpython-313"

shopt -s nullglob
packaged_charts=("${REPO_ROOT}"/charts/platform-stack/charts/openclaw-*.tgz)
shopt -u nullglob

for packaged_chart in "${packaged_charts[@]}"; do
  packaged_files="$(tar -tzf "${packaged_chart}")"
  assert_not_contains "${packaged_files}" "__pycache__"
  assert_not_contains "${packaged_files}" ".pyc"
done

echo "openclaw helmignore render test passed"
