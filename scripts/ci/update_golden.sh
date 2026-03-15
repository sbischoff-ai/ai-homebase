#!/usr/bin/env bash
set -euo pipefail

RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
CHART_PATH="${CHART_PATH:-charts/platform-stack}"
GOLDEN_DIR="${GOLDEN_DIR:-tests/golden}"

profiles=(
  "values=${CHART_PATH}/values.yaml"
  "values-dev=${CHART_PATH}/values-dev.yaml"
  "values-dev-k3d=${CHART_PATH}/values-dev.yaml,${CHART_PATH}/values-k3d.yaml"
  "values-aks=${CHART_PATH}/values-aks.yaml"
  "values-prod=${CHART_PATH}/values-prod.yaml"
)

mkdir -p "${GOLDEN_DIR}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

normalize_manifest() {
  local input_file="$1"
  local output_file="$2"

  python - "$input_file" "$output_file" <<'PY'
import sys
from pathlib import Path

try:
    import yaml
except ModuleNotFoundError as exc:
    raise SystemExit(
        "PyYAML is required for golden snapshot scripts. Install with: python -m pip install pyyaml"
    ) from exc

input_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])

stable_kinds = {
    "ConfigMap",
    "CronJob",
    "DaemonSet",
    "Deployment",
    "HorizontalPodAutoscaler",
    "Ingress",
    "Job",
    "PersistentVolumeClaim",
    "PodDisruptionBudget",
    "Secret",
    "Service",
    "ServiceAccount",
    "StatefulSet",
}


def cleanup(node):
    if isinstance(node, dict):
        for key in ["creationTimestamp", "managedFields", "resourceVersion", "uid", "selfLink", "generation"]:
            node.pop(key, None)

        metadata = node.get("metadata")
        if isinstance(metadata, dict):
            metadata.pop("creationTimestamp", None)
            annotations = metadata.get("annotations")
            if isinstance(annotations, dict):
                for key in [
                    "meta.helm.sh/release-name",
                    "meta.helm.sh/release-namespace",
                    "kubectl.kubernetes.io/last-applied-configuration",
                ]:
                    annotations.pop(key, None)
                if not annotations:
                    metadata.pop("annotations", None)

            labels = metadata.get("labels")
            if isinstance(labels, dict):
                labels.pop("helm.sh/chart", None)
                if not labels:
                    metadata.pop("labels", None)

        node.pop("status", None)

        for key, value in list(node.items()):
            cleanup(value)
            if value in (None, {}, []):
                node.pop(key, None)

    elif isinstance(node, list):
        for value in list(node):
            cleanup(value)


with input_path.open("r", encoding="utf-8") as fh:
    docs = [doc for doc in yaml.safe_load_all(fh) if isinstance(doc, dict)]

filtered = []
for doc in docs:
    if doc.get("kind") not in stable_kinds:
        continue
    cleanup(doc)
    filtered.append(doc)

filtered.sort(key=lambda d: (
    d.get("kind", ""),
    d.get("metadata", {}).get("namespace", ""),
    d.get("metadata", {}).get("name", ""),
))

with output_path.open("w", encoding="utf-8") as fh:
    for idx, doc in enumerate(filtered):
        if idx:
            fh.write("---\n")
        yaml.safe_dump(doc, fh, sort_keys=True)
PY
}

for profile in "${profiles[@]}"; do
  name="${profile%%=*}"
  values_csv="${profile#*=}"

  values_args=()
  IFS=',' read -ra values_files <<< "${values_csv}"
  for values_file in "${values_files[@]}"; do
    values_args+=(--values "${values_file}")
  done

  raw_file="${tmp_dir}/${name}.raw.yaml"
  output_file="${GOLDEN_DIR}/${name}.yaml"

  echo "Rendering snapshot for ${name}"
  helm template "${RELEASE_NAME}" "${CHART_PATH}" \
    --namespace "${NAMESPACE}" \
    "${values_args[@]}" \
    > "${raw_file}"

  normalize_manifest "${raw_file}" "${output_file}"
done

echo "Golden snapshots updated in ${GOLDEN_DIR}"
