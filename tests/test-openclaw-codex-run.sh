#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

bin_dir="${tmpdir}/bin"
workspace="${tmpdir}/workspace/repo"
home_dir="${tmpdir}/home"
mkdir -p "${bin_dir}" "${workspace}" "${home_dir}"

cat >"${bin_dir}/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" != "exec" ]]; then
  echo "unexpected codex command: $*" >&2
  exit 64
fi
shift

model=""
json="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      json="true"
      shift
      ;;
    --model)
      model="$2"
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

[[ "${json}" == "true" ]] || exit 65
[[ -n "${model}" ]] || exit 66
printf '{"type":"run_started","model":"%s"}\n' "${model}"
printf '{"type":"usage","input_tokens":123,"cached_input_tokens":45,"output_tokens":67}\n'
EOF

cat >"${bin_dir}/tokscale" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

jsonl_count="$(find "${TOKSCALE_HEADLESS_DIR}/codex" -type f -name '*.jsonl' | wc -l | tr -d ' ')"
if [[ "${jsonl_count}" != "1" ]]; then
  echo "expected exactly one isolated Codex JSONL file, found ${jsonl_count}" >&2
  exit 67
fi

printf '{"client":"codex","input_tokens":123,"cache_read_tokens":45,"output_tokens":67,"estimated_cost_usd":0.01}\n'
EOF

chmod 0755 "${bin_dir}/codex" "${bin_dir}/tokscale"

run_helper() {
  local run_id="$1"
  shift
  (
    cd "${workspace}"
    PATH="${bin_dir}:$PATH" \
      HOME="${home_dir}" \
      XDG_CONFIG_HOME="${home_dir}/.config" \
      XDG_STATE_HOME="${home_dir}/.local/state" \
      OPENCLAW_CODEX_ALLOW_ANY_WORKDIR=1 \
      CODEX_DEFAULT_MODEL="gpt-5.3-codex" \
      CODEX_ELEVATED_MODEL="gpt-5.5" \
      bash "${REPO_ROOT}/images/openclaw-sandbox-coder/openclaw-codex-run.sh" --foreground --run-id "${run_id}" "$@"
  )
}

run_helper normal-run -- "implement the thing"
run_helper elevated-run --elevated -- "debug the hard thing"

(
  cd "${workspace}"
  PATH="${bin_dir}:$PATH" \
    HOME="${home_dir}" \
    XDG_CONFIG_HOME="${home_dir}/.config" \
    XDG_STATE_HOME="${home_dir}/.local/state" \
    OPENCLAW_CODEX_ALLOW_ANY_WORKDIR=1 \
    CODEX_DEFAULT_MODEL="gpt-5.3-codex" \
    CODEX_ELEVATED_MODEL="gpt-5.5" \
    bash "${REPO_ROOT}/images/openclaw-sandbox-coder/openclaw-codex-run.sh" --run-id background-run -- "background implementation"
)

PATH="${bin_dir}:$PATH" \
  HOME="${home_dir}" \
  XDG_CONFIG_HOME="${home_dir}/.config" \
  XDG_STATE_HOME="${home_dir}/.local/state" \
  bash "${REPO_ROOT}/images/openclaw-sandbox-coder/openclaw-codex-run.sh" --wait background-run >/dev/null

python3 - "${home_dir}" <<'PY'
import json
import sys
from pathlib import Path

home = Path(sys.argv[1])
state = home / ".local/state/openclaw-codex-runs"

for run_id, expected_model, expected_elevated in [
    ("normal-run", "gpt-5.3-codex", False),
    ("elevated-run", "gpt-5.5", True),
    ("background-run", "gpt-5.3-codex", False),
]:
    run_dir = state / run_id
    assert (run_dir / "status").read_text().strip() == "completed"
    metadata = json.loads((run_dir / "metadata.json").read_text())
    assert metadata["model"] == expected_model
    assert metadata["elevated"] is expected_elevated
    assert Path(metadata["jsonl_path"]).is_file()
    assert Path(metadata["usage_report_path"]).is_file()
    usage = json.loads(Path(metadata["usage_report_path"]).read_text())
    assert usage["estimated_cost_usd"] == 0.01
    assert usage["input_tokens"] == 123
PY

echo "openclaw codex run helper test passed"
