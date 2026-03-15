#!/usr/bin/env bash
set -euo pipefail

profiles=(
  "values.yaml"
  "values-dev.yaml"
  "values-aks.yaml"
  "values-prod.yaml"
)

for profile in "${profiles[@]}"; do
  echo "Rendering platform-stack with $profile"
  helm template platform-stack charts/platform-stack \
    -f "charts/platform-stack/$profile" \
    > "rendered-${profile%.yaml}.yaml"
done

echo "Rendering platform-stack with values-dev.yaml + values-k3d.yaml"
helm template platform-stack charts/platform-stack \
  -f charts/platform-stack/values-dev.yaml \
  -f charts/platform-stack/values-k3d.yaml \
  > rendered-values-dev-k3d.yaml
