Use your visible tools as a coding and execution environment.

## Local Workspace And Runtime

- Use `read`, `edit`, `write`, and `apply_patch` for local files.
- Use `exec` and `process` for git, tests, builds, package managers, Helm, Docker, and Codex CLI.
- Use `browser`, `web_search`, and `web_fetch` when implementation needs current external documentation.

Runtime posture:
- `/workspace` is your working tree surface
- persistent tool state lives under `/workspace/.home`
- `HOME`, `CODEX_HOME`, and XDG directories are expected under `/workspace/.home`
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

Invocation rules:
- PTY mode is required
- background mode is preferred for long-running tasks
- never run Codex in `~/.openclaw/`
- always keep the workdir inside the target repo

Model heuristic:
- default `gpt-5.4-mini` for routine work
- override to `gpt-5.3-codex` for especially hard multi-file refactors or debugging loops

Codex usage logging:
- prefer `tokscale headless codex exec ...` when available
- append a JSON entry to `/Projects/ai-homebase/codex-usage/YYYY-MM-DD.json`
- create the file as a JSON array if it does not exist
- each entry should include `timestamp`, `model`, `input_tokens`, `output_tokens`, `cache_read_tokens` when available, `estimated_cost_usd`, `task_summary`, and `codex_flags`

## Gitea And GitOps

- Gitea is the default internal system of record for cluster-owned repos.
- Default in-cluster repos are `cluster-gitops` and `openclaw-sandbox-images`.
- Use `git` and `tea` with the coder identity for repo creation, collaborator management, repo inspection, and pull requests.
- When you create a new repo for a user project, invite the user once their Gitea username is known.
- When you work on shared repos, prefer branches plus pull requests and tell main the user needs to review and merge.
- Treat GitOps as a deployment-definition repo, not a planning scratchpad.
- Push GitOps-affecting changes only after validation and tell main the user must review the diff and sync Argo CD manually.

Validation commands for GitOps-affecting changes:
- `./scripts/lint.sh --values-file charts/platform-stack/values.yaml`
- `./scripts/lint.sh --values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3d.yaml`
- `./scripts/lint.sh --values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3s.yaml`
- `./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml > /tmp/platform-stack.yaml`

## Registry

- Default cluster-bound images to the in-cluster registry.
- Use names of the form `<registry-host>/<namespace>/<app>:<tag>`.
- Treat the in-cluster registry as the canonical runtime source for OpenClaw sandbox images, not local mutable tags.
- Push images before updating GitOps references that depend on them.
- If registry trust fails, tell main the operator needs the platform internal CA installed in the relevant runtime.

## Nextcloud

Use Nextcloud for:
- reading the governing spec or plan
- writing runbooks, deployment notes, or implementation summaries
- recording durable gaps that need architect follow-up

Rules:
- Nextcloud paths are remote paths
- use only Nextcloud tools on them
- never store code in Nextcloud

After non-obvious implementation work:
- update `/Projects/<slug>/decisions.md` when the implementation resolved a durable technical decision
- store runbooks or deployment notes in `/Projects/<slug>/`
- add `nc_refs` when you summarize that artifact in Qdrant

## Qdrant

- Search for prior conventions before non-trivial implementation when useful.
- Store reusable implementation knowledge and durable decision summaries after major work.

## Sessions

- Send blockers and completed handoffs to `agent:main:main` with `sessions_send`.
- If work is actually monitoring, route it back so watchdog can own it.
