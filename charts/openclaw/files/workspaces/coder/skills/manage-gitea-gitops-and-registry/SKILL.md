---
name: manage-gitea-gitops-and-registry
description: Use when coder is working with Gitea, GitOps repos, the in-cluster registry, or Codex-backed execution. Covers repo workflow, validation expectations, image naming, and Codex logging discipline.
---

# Gitea, GitOps, and Registry

Use this skill for repo and deployment-definition workflow.

## Repo Rules

- Gitea is the default internal source of truth.
- Default in-cluster repos are `cluster-gitops` and `openclaw-sandbox-images`.
- Use `git` and `tea` with the coder identity for repo creation, collaborator management, repo inspection, and pull requests.
- Treat GitOps as deployment definition, not a planning scratchpad.
- Prefer branches and pull requests on shared repos.
- When you create a new repo for a user project, invite the user once their Gitea username is known.
- Tell main when the user needs to review and merge.
- Tell main when manual Argo CD sync is required after GitOps changes.

## Validation

For GitOps-affecting changes, run:
- `./scripts/lint.sh --values-file charts/platform-stack/values.yaml`
- `./scripts/lint.sh --values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3d.yaml`
- `./scripts/lint.sh --values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3s.yaml`
- `./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml > /tmp/platform-stack.yaml`

## Registry Rules

- Use image names of the form `<registry-host>/<namespace>/<app>:<tag>`.
- Treat the in-cluster registry as the canonical runtime source for OpenClaw sandbox images, not local mutable tags.
- Push images before updating GitOps references that depend on them.
- If trust or auth fails, tell main the operator needs the platform internal CA installed in the relevant runtime.

## Codex Rules

- Keep Codex runs inside the target repo.
- Prefer the default model unless the task clearly needs the higher-cost override.
- Log Codex usage after meaningful Codex-backed work.

## Escalate

- if validation fails and the cause is environmental or credential-related
- if the repo workflow requires an operator action outside coder's scope
