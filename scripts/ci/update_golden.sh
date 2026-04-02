#!/usr/bin/env bash
set -euo pipefail

RELEASE_NAME="${RELEASE_NAME:-platform-stack}"
NAMESPACE="${NAMESPACE:-ai-homebase}"
CHART_PATH="${CHART_PATH:-charts/platform-stack}"
GOLDEN_DIR="${GOLDEN_DIR:-tests/golden}"

profiles=(
  "values=${CHART_PATH}/values.yaml"
  "values-k3d=${CHART_PATH}/values.yaml,${CHART_PATH}/values-k3d.yaml"
  "values-k3s=${CHART_PATH}/values.yaml,${CHART_PATH}/values-k3s.yaml"
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
    "Certificate",
    "ClusterIssuer",
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


class StableDumper(yaml.SafeDumper):
    pass


def represent_str(dumper, data):
    if "\n" in data:
        return dumper.represent_scalar("tag:yaml.org,2002:str", data, style="|")
    return dumper.represent_scalar("tag:yaml.org,2002:str", data)


StableDumper.add_representer(str, represent_str)


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
                    "updatedAt",
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
        yaml.dump(doc, fh, sort_keys=True, Dumper=StableDumper, width=10_000)
PY
}

render_openclaw_configmap_snapshot() {
  local input_file="$1"
  local output_file="$2"

  python - "$input_file" "$output_file" <<'PY'
import json
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


class StableDumper(yaml.SafeDumper):
    pass


def represent_str(dumper, data):
    if "\n" in data:
        return dumper.represent_scalar("tag:yaml.org,2002:str", data, style="|")
    return dumper.represent_scalar("tag:yaml.org,2002:str", data)


StableDumper.add_representer(str, represent_str)

with input_path.open("r", encoding="utf-8") as fh:
    docs = [doc for doc in yaml.safe_load_all(fh) if isinstance(doc, dict)]

configmaps = [
    doc for doc in docs
    if doc.get("kind") == "ConfigMap"
    and doc.get("metadata", {}).get("name") == "platform-stack-openclaw"
]

if len(configmaps) != 1:
    raise SystemExit(
        f"Expected exactly one platform-stack-openclaw ConfigMap in {input_path}, found {len(configmaps)}"
    )

configmap = configmaps[0]
data = configmap.get("data")
if not isinstance(data, dict):
    raise SystemExit(f"ConfigMap {input_path} is missing data")

openclaw_raw = data.get("openclaw.json")
if not isinstance(openclaw_raw, str):
    raise SystemExit(f"ConfigMap {input_path} is missing data['openclaw.json']")

openclaw = json.loads(openclaw_raw)

agents = openclaw.get("agents", {})
agent_list = agents.get("list")
if not isinstance(agent_list, list) or not agent_list:
    raise SystemExit(f"Rendered openclaw.json in {input_path} has no agents.list entries")

workspace_keys = {
    key.removeprefix("workspace-").split("-", 1)[0]
    for key in data
    if key.startswith("workspace-")
}

missing_workspaces = []
missing_models = []
for agent in agent_list:
    if not isinstance(agent, dict):
        raise SystemExit(f"Rendered openclaw.json in {input_path} has a non-object agent entry")
    agent_id = agent.get("id")
    if not isinstance(agent_id, str) or not agent_id:
        raise SystemExit(f"Rendered openclaw.json in {input_path} has an agent without a string id")
    model = agent.get("model")
    if not isinstance(model, dict) or not model.get("primary"):
        missing_models.append(agent_id)
    if agent_id not in workspace_keys:
        missing_workspaces.append(agent_id)

if missing_models:
    raise SystemExit(
        "Rendered openclaw.json is missing model.primary for agents: "
        + ", ".join(sorted(missing_models))
    )

if missing_workspaces:
    raise SystemExit(
        "OpenClaw ConfigMap is missing workspace bootstrap files for agents: "
        + ", ".join(sorted(missing_workspaces))
    )

with output_path.open("w", encoding="utf-8") as fh:
    yaml.dump(configmap, fh, sort_keys=True, Dumper=StableDumper, width=10_000)
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
  openclaw_output_file="${GOLDEN_DIR}/${name}-openclaw-configmap.yaml"

  echo "Rendering snapshot for ${name}"
  helm template "${RELEASE_NAME}" "${CHART_PATH}" \
    --namespace "${NAMESPACE}" \
    "${values_args[@]}" \
    > "${raw_file}"

  normalize_manifest "${raw_file}" "${output_file}"
  render_openclaw_configmap_snapshot "${raw_file}" "${openclaw_output_file}"
done

echo "Golden snapshots updated in ${GOLDEN_DIR}"
