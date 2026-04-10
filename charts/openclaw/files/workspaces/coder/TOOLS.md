# Tools

Local notes for this setup.

## Runtime

- `/workspace` is the repo working tree.
- Persistent tool state lives under `/workspace/.home`.
- `HOME`, `CODEX_HOME`, and XDG directories are already pointed into `/workspace/.home`.
- Use `CODER_GITEA_BASE_URL` / `CODER_GITEA_HOST` for the in-cluster Gitea service.
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

- Keep Codex runs inside the target repo.
- Use repo-local worktrees when you need parallel isolation.
- Do not create a persistent local OpenClaw `CURRENT.md` or `SURFACES.md` in this sandbox. Keep short-term continuity repo-local and mirror outward only when another agent or the user needs it.
- Keep this file current when sandbox paths, runtime env vars, or canonical repo names change.
