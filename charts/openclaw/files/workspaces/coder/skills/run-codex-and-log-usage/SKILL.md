---
name: run-codex-and-log-usage
description: Use when invoking Codex CLI or recording Codex usage for implementation work.
---

# Codex Execution And Logging

Use for Codex-backed implementation work.

## Invocation Rules

- PTY mode is required
- background mode is preferred for long-running tasks
- never run Codex in `~/.openclaw/`
- always keep the workdir inside the target repo
- use repo-local worktrees when parallel isolation is needed

## Model Heuristic

- default `gpt-5.4-mini` for routine work
- override to `gpt-5.3-codex` for especially hard multi-file refactors or debugging loops

## Usage Logging

- if Codex was used and the session is not explicitly off-budget, log usage before returning to main
- prefer `tokscale headless codex exec ...` when available
- append a JSON entry to Nextcloud `/Projects/ai-homebase/codex-usage/YYYY-MM-DD.json`
- create the file as a JSON array if it does not exist
- each entry should include `timestamp`, `model`, `input_tokens`, `output_tokens`, `cache_read_tokens` when available, `estimated_cost_usd`, `task_summary`, and `codex_flags`

## Ownership

Keep direct ownership of:
- repo state
- validation
- commit and PR workflow
- final handoff quality
