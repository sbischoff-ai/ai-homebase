#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  openclaw-codex-run [--elevated] [--model MODEL] [--foreground] [--run-id ID] -- PROMPT...
  openclaw-codex-run --status RUN_ID
  openclaw-codex-run --tail RUN_ID
  openclaw-codex-run --wait RUN_ID

Runs Codex from a /workspace repo, captures Codex JSONL for tokscale, and writes
per-run metadata under XDG_STATE_HOME/openclaw-codex-runs.
EOF
}

fail() {
  echo >&2 "ERROR: $*"
  exit 1
}

json_string() {
  python3 -c 'import json, sys; print(json.dumps(sys.stdin.read()))'
}

state_root() {
  local home_dir="${HOME:-/workspace/.home}"
  local xdg_state="${XDG_STATE_HOME:-${home_dir}/.local/state}"
  printf '%s/openclaw-codex-runs\n' "${xdg_state}"
}

status_file_for() {
  printf '%s/%s/status\n' "$(state_root)" "$1"
}

metadata_file_for() {
  printf '%s/%s/metadata.json\n' "$(state_root)" "$1"
}

stdout_file_for() {
  printf '%s/%s/stdout.log\n' "$(state_root)" "$1"
}

stderr_file_for() {
  printf '%s/%s/stderr.log\n' "$(state_root)" "$1"
}

jsonl_path_for() {
  python3 - "$1" <<'PY'
import json
import sys
from pathlib import Path

metadata_path = Path(sys.argv[1])
if not metadata_path.is_file():
    raise SystemExit(1)
payload = json.loads(metadata_path.read_text())
print(payload.get("jsonl_path", ""))
PY
}

write_metadata() {
  local metadata_path="$1"
  local run_id="$2"
  local model="$3"
  local elevated="$4"
  local cwd="$5"
  local jsonl_path="$6"
  local usage_report_path="$7"
  local started_at="$8"
  shift 8
  python3 - "$metadata_path" "$run_id" "$model" "$elevated" "$cwd" "$jsonl_path" "$usage_report_path" "$started_at" "$@" <<'PY'
import json
import sys
from pathlib import Path

metadata_path, run_id, model, elevated, cwd, jsonl_path, usage_report_path, started_at, *prompt = sys.argv[1:]
payload = {
    "run_id": run_id,
    "model": model,
    "elevated": elevated == "true",
    "cwd": cwd,
    "jsonl_path": jsonl_path,
    "usage_report_path": usage_report_path,
    "started_at": started_at,
    "prompt": " ".join(prompt),
}
Path(metadata_path).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
PY
}

update_metadata_exit() {
  local metadata_path="$1"
  local ended_at="$2"
  local exit_code="$3"
  python3 - "$metadata_path" "$ended_at" "$exit_code" <<'PY'
import json
import sys
from pathlib import Path

metadata_path = Path(sys.argv[1])
ended_at = sys.argv[2]
exit_code = int(sys.argv[3])
payload = json.loads(metadata_path.read_text())
payload["ended_at"] = ended_at
payload["exit_code"] = exit_code
metadata_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
PY
}

copy_run_into_isolated_tokscale_home() {
  local jsonl_path="$1"
  local isolated_headless="$2"
  local client_dir="${isolated_headless}/codex"

  mkdir -p "${client_dir}"
  cp -f "${jsonl_path}" "${client_dir}/$(basename "${jsonl_path}")"
}

write_usage_report() {
  local jsonl_path="$1"
  local usage_report_path="$2"
  local run_dir="$3"
  local isolated_config
  isolated_config="$(mktemp -d "${run_dir}/tokscale-config.XXXXXX")"
  local isolated_headless="${isolated_config}/headless"
  copy_run_into_isolated_tokscale_home "${jsonl_path}" "${isolated_headless}"

  if TOKSCALE_CONFIG_DIR="${isolated_config}" TOKSCALE_HEADLESS_DIR="${isolated_headless}" tokscale --client codex --json >"${usage_report_path}" 2>"${run_dir}/tokscale.stderr.log"; then
    return 0
  fi

  if TOKSCALE_CONFIG_DIR="${isolated_config}" TOKSCALE_HEADLESS_DIR="${isolated_headless}" tokscale --json >"${usage_report_path}" 2>"${run_dir}/tokscale.stderr.log"; then
    return 0
  fi

  return 1
}

run_foreground() {
  local run_id="$1"
  local model="$2"
  local elevated="$3"
  shift 3

  [[ $# -gt 0 ]] || fail "Codex prompt is required."
  case "$(pwd)" in
    /workspace|/workspace/*) ;;
    *)
      if [[ "${OPENCLAW_CODEX_ALLOW_ANY_WORKDIR:-}" != "1" ]]; then
        fail "openclaw-codex-run must be started from a target repo under /workspace."
      fi
      ;;
  esac

  command -v codex >/dev/null 2>&1 || fail "codex CLI is unavailable."
  command -v tokscale >/dev/null 2>&1 || fail "tokscale is unavailable."

  local home_dir="${HOME:-/workspace/.home}"
  local xdg_config="${XDG_CONFIG_HOME:-${home_dir}/.config}"
  local run_root capture_dir run_dir started_at safe_run_id jsonl_path usage_report_path metadata_path stdout_path stderr_path
  run_root="$(state_root)"
  capture_dir="${TOKSCALE_HEADLESS_DIR:-${xdg_config}/tokscale/headless}/codex"
  safe_run_id="${run_id//[^A-Za-z0-9_.-]/-}"
  run_dir="${run_root}/${safe_run_id}"
  started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  jsonl_path="${capture_dir}/codex-${started_at//[:]/-}-${safe_run_id}.jsonl"
  usage_report_path="${run_dir}/tokscale-usage.json"
  metadata_path="${run_dir}/metadata.json"
  stdout_path="${run_dir}/stdout.log"
  stderr_path="${run_dir}/stderr.log"

  mkdir -p "${run_dir}" "${capture_dir}"
  printf 'running\n' >"${run_dir}/status"
  write_metadata "${metadata_path}" "${safe_run_id}" "${model}" "${elevated}" "$(pwd)" "${jsonl_path}" "${usage_report_path}" "${started_at}" "$@"

  set +e
  codex exec --json --model "${model}" "$@" >"${jsonl_path}" 2>"${stderr_path}"
  local codex_exit=$?
  set -e
  cp -f "${jsonl_path}" "${stdout_path}"

  local ended_at
  ended_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  update_metadata_exit "${metadata_path}" "${ended_at}" "${codex_exit}"

  if [[ -s "${jsonl_path}" ]] && write_usage_report "${jsonl_path}" "${usage_report_path}" "${run_dir}"; then
    :
  else
    printf 'usage-blocked\n' >"${run_dir}/status"
    echo >&2 "Tokscale usage report failed for run ${safe_run_id}; see ${run_dir}/tokscale.stderr.log."
    return 2
  fi

  if [[ "${codex_exit}" -eq 0 ]]; then
    printf 'completed\n' >"${run_dir}/status"
  else
    printf 'failed\n' >"${run_dir}/status"
  fi
  return "${codex_exit}"
}

show_status() {
  local run_id="$1"
  local metadata_path status_path
  metadata_path="$(metadata_file_for "${run_id}")"
  status_path="$(status_file_for "${run_id}")"
  [[ -f "${metadata_path}" ]] || fail "unknown Codex run: ${run_id}"
  python3 - "$metadata_path" "$status_path" <<'PY'
import json
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text())
status = Path(sys.argv[2]).read_text().strip() if Path(sys.argv[2]).is_file() else "unknown"
metadata["status"] = status
print(json.dumps(metadata, indent=2, sort_keys=True))
PY
}

tail_run() {
  local run_id="$1"
  local jsonl_path
  jsonl_path="$(jsonl_path_for "$(metadata_file_for "${run_id}")")"
  [[ -n "${jsonl_path}" && -f "${jsonl_path}" ]] || fail "Codex JSONL not found for run: ${run_id}"
  tail -f "${jsonl_path}"
}

wait_run() {
  local run_id="$1"
  local status_path
  status_path="$(status_file_for "${run_id}")"
  local metadata_path
  metadata_path="$(metadata_file_for "${run_id}")"
  local attempts=0
  while [[ ! -f "${metadata_path}" && "${attempts}" -lt 30 ]]; do
    attempts=$((attempts + 1))
    sleep 1
  done
  [[ -f "${metadata_path}" ]] || fail "unknown Codex run: ${run_id}"
  while true; do
    local status
    status="$(cat "${status_path}" 2>/dev/null || printf unknown)"
    case "${status}" in
      completed|failed|usage-blocked)
        show_status "${run_id}"
        [[ "${status}" == "completed" ]]
        return
        ;;
    esac
    sleep 2
  done
}

main() {
  local default_model="${CODEX_DEFAULT_MODEL:-gpt-5.3-codex}"
  local elevated_model="${CODEX_ELEVATED_MODEL:-gpt-5.5}"
  local model="${default_model}"
  local elevated="false"
  local foreground="false"
  local run_id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        usage
        return 0
        ;;
      --elevated)
        elevated="true"
        model="${elevated_model}"
        shift
        ;;
      --model)
        [[ $# -ge 2 ]] || fail "--model requires a value."
        model="$2"
        shift 2
        ;;
      --foreground)
        foreground="true"
        shift
        ;;
      --run-id)
        [[ $# -ge 2 ]] || fail "--run-id requires a value."
        run_id="$2"
        shift 2
        ;;
      --status)
        [[ $# -ge 2 ]] || fail "--status requires a run id."
        show_status "$2"
        return 0
        ;;
      --tail)
        [[ $# -ge 2 ]] || fail "--tail requires a run id."
        tail_run "$2"
        return 0
        ;;
      --wait)
        [[ $# -ge 2 ]] || fail "--wait requires a run id."
        wait_run "$2"
        return $?
        ;;
      --)
        shift
        break
        ;;
      -*)
        fail "unknown option: $1"
        ;;
      *)
        break
        ;;
    esac
  done

  [[ $# -gt 0 ]] || fail "Codex prompt is required."
  if [[ -z "${run_id}" ]]; then
    run_id="$(date -u +%Y%m%dT%H%M%SZ)-${RANDOM}${RANDOM}"
  fi
  run_id="${run_id//[^A-Za-z0-9_.-]/-}"

  if [[ "${foreground}" == "true" ]]; then
    run_foreground "${run_id}" "${model}" "${elevated}" "$@"
    return $?
  fi

  command -v tmux >/dev/null 2>&1 || fail "tmux is unavailable; rerun with --foreground or install tmux."
  local session="codex-${run_id}"
  local tmux_args=("$0" --foreground --run-id "${run_id}" --model "${model}")
  if [[ "${elevated}" == "true" ]]; then
    tmux_args+=(--elevated)
  fi
  tmux_args+=("$@")
  tmux new-session -d -s "${session}" -c "$(pwd)" -- "${tmux_args[@]}"
  printf 'started Codex run %s in tmux session %s\n' "${run_id}" "${session}"
  printf 'status: openclaw-codex-run --status %s\n' "${run_id}"
  printf 'tail:   openclaw-codex-run --tail %s\n' "${run_id}"
  printf 'wait:   openclaw-codex-run --wait %s\n' "${run_id}"
}

main "$@"
