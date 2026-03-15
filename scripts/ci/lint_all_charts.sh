#!/usr/bin/env bash
set -euo pipefail

CHARTS_DIR="${CHARTS_DIR:-charts}"

mapfile -t charts < <(find "${CHARTS_DIR}" -mindepth 1 -maxdepth 1 -type d | sort)
for chart in "${charts[@]}"; do
  if [[ -f "${chart}/Chart.yaml" ]]; then
    echo "Linting ${chart}"
    helm lint "${chart}"
  fi
done
