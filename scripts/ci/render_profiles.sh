#!/usr/bin/env bash
set -euo pipefail

RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
CHART_PATH="${CHART_PATH:-charts/platform-stack}"
OUTPUT_PREFIX="${OUTPUT_PREFIX:-rendered}"

profiles=(
  "values.yaml"
  "values-k3d.yaml"
  "values-k3s.yaml"
)

for profile in "${profiles[@]}"; do
  echo "Rendering ${RELEASE_NAME} with ${profile}"
  values_args=(-f "${CHART_PATH}/values.yaml")
  if [[ "$profile" != "values.yaml" ]]; then
    values_args+=(-f "${CHART_PATH}/${profile}")
  fi
  helm template "${RELEASE_NAME}" "${CHART_PATH}" \
    "${values_args[@]}" \
    > "${OUTPUT_PREFIX}-${profile%.yaml}.yaml"
done
