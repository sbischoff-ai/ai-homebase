---
name: run-codex-and-log-usage
description: Use for non-trivial implementation work. Delegate the coding or large-repo analysis to Codex CLI, then record usage before handing back results.
---

# Codex Execution And Logging

Use this skill whenever the task involves meaningful code generation, refactoring, debugging, or broad codebase analysis.

## Invocation Rules

- prefer `tokscale headless codex exec ...` when available
- otherwise use `codex exec ...`
- PTY mode is required
- background mode is preferred for long-running tasks
- never run Codex in `~/.openclaw/`
- always keep the workdir inside the target repo
- use repo-local worktrees when parallel isolation is needed
- keep direct manual edits for tiny fixes, integration glue, or post-Codex cleanup
- if Codex is unavailable or auth fails, stop and report the blocker instead of coding around it inline

## Model Heuristic

- default `gpt-5.4-mini` for routine work
- override to `gpt-5.3-codex` for especially hard multi-file refactors or debugging loops

## Usage Logging

- if Codex was used and the session is not explicitly off-budget, log usage before returning to main
- `tokscale` is the source of truth for usage metrics in this stack
- prefer `tokscale headless codex exec ...` because it wraps the Codex run and gives you the token and cost numbers needed for logging
- when `tokscale` produced the run, copy the reported `input_tokens`, `output_tokens`, `cache_read_tokens` when present, and `estimated_cost_usd` directly from its output instead of estimating them yourself
- if you had to use bare `codex exec`, do not guess usage from memory or rough pricing math; fetch the exact numbers from `tokscale` before writing the log entry, or report that accurate logging is blocked
- append a JSON entry to Nextcloud `/Projects/ai-homebase/codex-usage/YYYY-MM-DD.json`
- create the file as a JSON array if it does not exist
- each entry should include `timestamp`, `model`, `input_tokens`, `output_tokens`, `cache_read_tokens` when available, `estimated_cost_usd`, `task_summary`, and `codex_flags`

## Ownership

Keep direct ownership of:
- repo state
- validation
- commit and PR workflow
- final handoff quality
