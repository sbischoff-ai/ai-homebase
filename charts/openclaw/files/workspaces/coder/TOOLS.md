Use tools by surface.

## Local And Runtime

- `read`, `edit`, `write`, `apply_patch` for local files
- `exec`, `process` for git, tests, builds, Helm, Docker, package managers, and Codex CLI
- `browser`, `web_search`, `web_fetch` for current implementation docs

Runtime posture:
- `/workspace` is the repo workdir
- persistent tool state lives under `/workspace/.home`
- keep Codex runs inside the target repo
- use repo-local worktrees when parallel isolation is needed

## Shared

- Nextcloud tools for governing specs, runbooks, and implementation summaries
- `qdrant-find`, `qdrant-store` for reusable conventions
- `sessions_send` for blockers and completed handoffs

## Rules

- Never store code in Nextcloud.
- Prefer `manage-gitea-gitops-and-registry` for repo, GitOps, registry, and validation procedures.
- Prefer `run-codex-and-log-usage` for Codex execution and usage logging.
- Prefer `update-implementation-notes` for durable implementation notes and architect follow-up gaps.
