#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

render_file="${tmpdir}/platform-stack.yaml"

(
  cd "${REPO_ROOT}"
  nix-shell --run "./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml > ${render_file}"
)

rendered_manifest="$(cat "${render_file}")"

if [[ "${rendered_manifest}" != *"normalize_seeded_skill() {"* ]]; then
  printf 'expected rendered deployment to include workspace skill normalization helper\n' >&2
  exit 1
fi

if [[ "${rendered_manifest}" != *"sed '1{/^$/d;}'"* ]]; then
  printf 'expected rendered deployment to strip a leading blank line from seeded SKILL.md files\n' >&2
  exit 1
fi

if [[ "${rendered_manifest}" != *"if [ \"\$(basename \"\${target_path}\")\" != \"SKILL.md\" ]; then"* ]]; then
  printf 'expected rendered deployment to scope normalization to SKILL.md files\n' >&2
  exit 1
fi

echo "openclaw workspace skill render test passed"
