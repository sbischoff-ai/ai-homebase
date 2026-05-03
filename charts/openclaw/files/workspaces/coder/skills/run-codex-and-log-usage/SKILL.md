---
name: run-codex-and-log-usage
description: Use for non-trivial implementation work. Delegate the coding or large-repo analysis to Codex CLI, then record usage before handing back results.
---

# Codex Execution And Logging

Use this skill whenever the task involves meaningful code generation, refactoring, debugging, or broad codebase analysis.

## Invocation Rules

- prefer `openclaw-codex-run -- "..."` for non-trivial Codex work
- use `openclaw-codex-run --elevated -- "..."` only for extra complex tasks or unusually large codebases
- the helper starts Codex in a durable `tmux` session by default and records run state under `/workspace/.home/.local/state/openclaw-codex-runs/`
- use `openclaw-codex-run --status <run-id>`, `--tail <run-id>`, and `--wait <run-id>` to monitor the run instead of assuming the surrounding OpenClaw exec session is the lifecycle boundary
- use `openclaw-codex-run --foreground -- "..."` only for short diagnostic runs where an outer timeout cannot kill useful work
- never run Codex in `~/.openclaw/`
- always keep the workdir inside the target repo
- use repo-local worktrees when parallel isolation is needed
- keep direct manual edits for tiny fixes, integration glue, or post-Codex cleanup
- if the helper, Codex, Tokscale, or auth fails, stop and report the concrete blocker instead of coding around it inline

## Model Heuristic

- default `gpt-5.3-codex` for implementation work
- elevated `gpt-5.5` for extra complex debugging loops, broad refactors, or unfamiliar large codebases
- prefer the default model unless the task clearly needs the higher-cost elevated model

## Usage Logging

- if Codex was used and the session is not explicitly off-budget, log usage before returning to main
- `tokscale` is the source of truth for usage metrics in this stack
- `openclaw-codex-run` captures Codex `--json` output under `/workspace/.home/.config/tokscale/headless/codex/` and writes a per-run Tokscale report path in its status JSON
- copy usage fields from the helper's Tokscale report; do not expect `estimated_cost_usd` to be present in raw Codex JSONL
- if the Tokscale report is missing or incomplete, do not guess usage from memory or rough pricing math; report that accurate logging is blocked
- append a JSON entry to Nextcloud `/Projects/ai-homebase/codex-usage/YYYY-MM-DD.json`
- create the file as a JSON array if it does not exist
- each entry should include `timestamp`, `model`, `input_tokens`, `output_tokens`, `cache_read_tokens` when available, `estimated_cost_usd`, `task_summary`, `run_id`, `jsonl_path`, `usage_report_path`, and `codex_flags`

## Ownership

Keep direct ownership of:
- repo state
- validation
- commit and PR workflow
- final handoff quality
