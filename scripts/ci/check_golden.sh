#!/usr/bin/env bash
set -euo pipefail

EXPECTED_DIR="${GOLDEN_DIR:-tests/golden}"

if [[ ! -d "${EXPECTED_DIR}" ]]; then
  echo "Missing ${EXPECTED_DIR}. Run scripts/ci/update_golden.sh first." >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

GOLDEN_DIR="${tmp_dir}" scripts/ci/update_golden.sh > /dev/null

failed=0
while IFS= read -r expected; do
  file_name="$(basename "${expected}")"
  actual="${tmp_dir}/${file_name}"

  if ! diff -u "${expected}" "${actual}"; then
    echo "Golden mismatch: ${file_name}" >&2
    failed=1
  fi
done < <(find "${EXPECTED_DIR}" -maxdepth 1 -type f -name '*.yaml' | sort)

if [[ ${failed} -ne 0 ]]; then
  echo "Snapshot check failed. If changes are intentional, run scripts/ci/update_golden.sh and commit updated fixtures." >&2
  exit 1
fi

echo "Golden snapshots are up to date."
