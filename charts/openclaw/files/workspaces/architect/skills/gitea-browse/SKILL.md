---
name: gitea-browse
description: Browse in-cluster Gitea repos, issues, pull requests, commits, chart values, GitOps definitions, and sandbox image sources for read-only design context with the `__REVIEWER_GITEA_USERNAME__` Gitea user shared with auditor.
---

# Gitea Browse

Use this skill to inspect in-cluster source control before design work.

## Default Repos

- `cluster-gitops` - GitOps deployment definitions, platform-stack charts, values, and cluster handoff material
- `openclaw-sandbox-images` - Dockerfiles and image build configs for agent sandbox runtimes

## Read-Only Commands

Use the preconfigured `git` and `tea` access for the `__REVIEWER_GITEA_USERNAME__` Gitea user. Auditor uses this same Gitea user for review work. Coder uses the separate `__CODER_GITEA_USERNAME__` Gitea user for implementation and repo management.

```bash
tea repo view __CODER_GITEA_USERNAME__/cluster-gitops --login "$REVIEWER_GITEA_TEA_LOGIN_NAME"
tea repo view __CODER_GITEA_USERNAME__/openclaw-sandbox-images --login "$REVIEWER_GITEA_TEA_LOGIN_NAME"
tea issue list --repo <owner>/<repo> --state open --login "$REVIEWER_GITEA_TEA_LOGIN_NAME"
tea issue view <number> --repo <owner>/<repo> --login "$REVIEWER_GITEA_TEA_LOGIN_NAME"
tea pr list --repo <owner>/<repo> --state open --login "$REVIEWER_GITEA_TEA_LOGIN_NAME"
tea pr view <number> --repo <owner>/<repo> --login "$REVIEWER_GITEA_TEA_LOGIN_NAME"
```

Clone only for inspection, keep the clone in a temporary directory, then discard it.

```bash
clone_root="$(mktemp -d "${TMPDIR:-/tmp}/gitea-browse.XXXXXX")"
git clone "${REVIEWER_GITEA_BASE_URL%/}/<owner>/<repo>.git" "${clone_root}/<repo>"
cd "${clone_root}/<repo>"
git ls-tree -r HEAD --name-only
git show HEAD:path/to/file.yaml
git show <sha>:path/to/file.yaml
git log --oneline -20
git log --oneline -- path/to/file.yaml
git show <sha> --stat
rm -rf "${clone_root}"
```

## Rules

- Do not push branches, open pull requests, create commits, merge, or modify repo state.
- Do not stage or commit changes.
- The Gitea admin account `__GITEA_ADMIN_USERNAME__` remains the final authority for approvals and merges on protected `main`.
- Cite concrete repo paths, commits, issues, or PRs when they shape a design.
- Tell main when a design depends on absent, ambiguous, or inconsistent Gitea state.
- Use `--login "$REVIEWER_GITEA_TEA_LOGIN_NAME"` for `tea` commands so the shared reviewer account is selected consistently.
- If `tea` auth fails or a critical repo is missing, stop and tell main exactly what failed.
