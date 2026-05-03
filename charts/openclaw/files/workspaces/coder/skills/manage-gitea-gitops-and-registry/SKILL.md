---
name: manage-gitea-gitops-and-registry
description: Use for Gitea, GitOps, registry, and every non-trivial implementation task that should be delegated to Codex instead of being coded inline.
---

# Gitea, GitOps, and Registry

Use for repo and deployment-definition workflow.

## Repo Rules

- Gitea is the default internal source of truth.
- Default in-cluster repos are `cluster-gitops` and `openclaw-sandbox-images`.
- Use the preconfigured `git` and `tea` access for the `__CODER_GITEA_USERNAME__` Gitea user for repo creation, collaborator management, repo inspection, and pull requests.
- Keep repo clones and worktrees under `/workspace`, not `/tmp`, so file tools and Codex can operate on them directly.
- For `cluster-gitops` and `openclaw-sandbox-images`, start Codex from the target repo root under `/workspace`.
- Treat GitOps as deployment definition, not a planning scratchpad.
- Prefer branches and pull requests on shared repos.
- On every repo you create, add `__GITEA_ADMIN_USERNAME__` as an admin collaborator. Protected `main` must still allow `__GITEA_ADMIN_USERNAME__` to approve and merge pull requests.
- When you create a new internal repo, add the shared reviewer account `__REVIEWER_GITEA_USERNAME__` as a collaborator so architect and auditor can review through that identity.
- Keep the default internal posture review-first: protected `main`, pull requests, and reviewer approval before merge unless main explicitly says a repo should differ.
- Tell main when the user needs to review and merge.
- Tell main when manual Argo CD sync is required after GitOps changes.
- If `tea` fails, diagnose it explicitly. One temporary `tea <subcommand> ... --login "$CODER_GITEA_TEA_LOGIN_NAME"` retry is acceptable to confirm login-selection trouble. Do not silently switch to raw `curl` with embedded credentials for normal repo workflow.
- Before applying design or audit feedback that changes deployable structure, verify the destination path is actually wired into the repo's deployment flow. If the spec conflicts with the live repo architecture, stop and report the mismatch.

## Registry Rules

- Use image names of the form `<registry-host>/<namespace>/<app>:<tag>`.
- Treat the in-cluster registry as the canonical runtime source for OpenClaw sandbox images, not local mutable tags.
- Push images before updating GitOps references that depend on them.
- If trust or auth fails, tell main the operator needs the platform internal CA installed in the relevant runtime.

## Codex Rules

- Use Codex for non-trivial code generation, refactors, debugging loops, and large-repo analysis. Your job is to orchestrate repo-local Codex work, then keep ownership of repo state, validation, and handoff quality.
- Direct manual edits are only for tiny mechanical fixes, final integration, or validation glue around Codex output.
- Keep Codex runs inside the target repo under `/workspace`, with the workdir at the repo root.
- Prefer the default model unless the task clearly needs the higher-cost override.
- If Codex auth or the CLI is broken, stop and tell main exactly what failed.
- Log Codex usage after meaningful Codex-backed work.

## Escalate

- if validation fails and the cause is environmental or credential-related
- if the repo workflow requires an operator action outside coder's scope
- if `tea` or Codex is unavailable after one focused diagnostic pass
