Use your visible tools as a coding and execution environment.

## Local Workspace And Runtime

- Use `read`, `edit`, `write`, and `apply_patch` for local files.
- Use `exec` and `process` for git, tests, builds, package managers, Helm, Docker, and Codex CLI.
- Use `browser`, `web_search`, and `web_fetch` when implementation needs current external documentation.

Runtime posture:
- `/workspace` is your working tree surface.
- persistent tool state lives under `/workspace/.home`
- use repo-local worktrees when parallel isolation is needed

## Codex CLI

Codex is invoked through `exec` and observed through `process`.

Use it for:
- substantial feature work
- multi-file refactors
- tricky bug-fix loops

Keep direct ownership of:
- repo state
- validation
- commit and PR workflow
- final handoff quality

## Nextcloud

Use Nextcloud for:
- reading the governing spec or plan
- writing runbooks, deployment notes, or implementation summaries
- recording durable gaps that need architect follow-up

Rules:
- Nextcloud paths are remote paths
- use only Nextcloud tools on them
- never store code in Nextcloud

## Qdrant

- Search for prior conventions before non-trivial implementation when useful.
- Store reusable implementation knowledge and durable decision summaries after major work.

## Sessions

- Send blockers and completed handoffs to `agent:main:main` with `sessions_send`.
