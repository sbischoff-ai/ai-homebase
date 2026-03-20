#!/usr/bin/env bash
set -euo pipefail

scan_targets=(
  "README.md"
  "docs"
  "examples"
  "charts/platform-stack/values.yaml"
  "charts/platform-stack/values-k3d.yaml"
  "charts/platform-stack/values-k3s.yaml"
  "charts/platform-stack/values.schema.json"
  "charts/paperless-ngx/values.yaml"
)

patterns=(
  'global\.hosts\.paperless(\b|[^A-Za-z0-9_])'
  '^[[:space:]]+paperless:[[:space:]]'
)

failed=0
for pattern in "${patterns[@]}"; do
  if rg -n --pcre2 "$pattern" "${scan_targets[@]}"; then
    failed=1
  fi
done

if [[ "$failed" -ne 0 ]]; then
  echo "Legacy Paperless host keys found. Use only global.hosts.paperlessNgx." >&2
  exit 1
fi

echo "Canonical host key check passed."
