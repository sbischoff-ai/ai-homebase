#!/usr/bin/env bash
set -euo pipefail

RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
CHART_PATH="${CHART_PATH:-charts/platform-stack}"
OUTPUT_PREFIX="${OUTPUT_PREFIX:-rendered}"

profiles=(
  "values.yaml"
  "values-dev.yaml"
  "values-aks.yaml"
  "values-prod.yaml"
)

for profile in "${profiles[@]}"; do
  echo "Rendering ${RELEASE_NAME} with ${profile}"
  helm template "${RELEASE_NAME}" "${CHART_PATH}" \
    -f "${CHART_PATH}/${profile}" \
    > "${OUTPUT_PREFIX}-${profile%.yaml}.yaml"
done

echo "Rendering ${RELEASE_NAME} with layered dev+k3d profile"
helm template "${RELEASE_NAME}" "${CHART_PATH}" \
  -f "${CHART_PATH}/values-dev.yaml" \
  -f "${CHART_PATH}/values-k3d.yaml" \
  > "${OUTPUT_PREFIX}-values-dev-k3d.yaml"
