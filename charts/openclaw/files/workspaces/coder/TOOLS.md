# Tools

This file records how this OpenClaw setup expects you to use your available tools and skills. It distinguishes repo-local files from remote Nextcloud paths where that matters.

## Runtime

- `/workspace` is the writable repo root for implementation work.
- Clone repos, create worktrees, and run Codex only under `/workspace`.
- Use `/tmp` only for disposable artifacts such as rendered manifests, logs, or one-shot scratch output that does not need workspace file tools.
- Persistent tool state lives under `/workspace/.home`.
- `HOME`, `CODEX_HOME`, and XDG directories are already pointed into `/workspace/.home`.
- Remote Docker access is prewired through `DOCKER_HOST`; the SSH key material lives under `/workspace/.home/.ssh`.
- Use `CODER_GITEA_BASE_URL` / `CODER_GITEA_HOST` for the configured sandbox-reachable Gitea endpoint.
- `CODER_GITEA_TOKEN` and `CODER_GITEA_TEA_LOGIN_NAME` are the preferred tea login inputs. `CODER_GITEA_PASSWORD` remains available for git/basic-auth and bootstrap fallback only.
- Use `CODER_REGISTRY_BASE_URL` / `CODER_REGISTRY_HOST` for the in-cluster registry.
- Canonical repo names in this stack:
  - GitOps: `cluster-gitops`
  - sandbox images: `openclaw-sandbox-images`

## Files

- Files in the active repo under `/workspace` are local workspace files.
- Repo-local docs, README files, AGENTS files, and task notes are your short-term continuity surface.
- Nextcloud `/Projects/...` are remote paths for durable implementation context, runbooks, and user-facing handoff artifacts.
- Keep private debugging notes and scratch work in the repo or workspace until they become durable conventions or summaries worth sharing.
- Use Qdrant for reusable technical conventions and quick recall that should survive the session without becoming a standalone doc.
- Use `project`, `tags`, and `nc_refs` so later implementation work can find the right convention quickly.
- If you create a recurring shared Nextcloud surface outside Nextcloud `/Projects/<slug>/`, make sure main or the owning agent registers it in Nextcloud `/Desk/index.md`.
- Shared ai-homebase docs you will commonly read or update:
  - Nextcloud `/Projects/ai-homebase/gitops-workflow.md`
  - Nextcloud `/Projects/ai-homebase/cluster-architecture.md`
  - Nextcloud `/Projects/ai-homebase/budget-policy.md`
  - Nextcloud `/Projects/ai-homebase/codex-usage/`

## Sessions

- Return blockers and completed handoffs to `agent:main:main`.

## Notes

- Keep Codex runs inside the target repo under `/workspace`.
- Start Codex from the target repo root.
- If `tea` fails, diagnose the configured login before falling back to any lower-level API access. A temporary `tea <subcommand> ... --login "$CODER_GITEA_TEA_LOGIN_NAME"` check is acceptable for diagnosis.
- Use repo-local worktrees when you need parallel isolation.
- Do not create a persistent local OpenClaw `CURRENT.md` or `SURFACES.md` in this sandbox. Keep short-term continuity repo-local and mirror outward only when another agent or the user needs it.
- Keep this file current when sandbox paths, runtime env vars, or canonical repo names change.
