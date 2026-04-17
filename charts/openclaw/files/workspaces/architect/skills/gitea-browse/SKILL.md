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
tea repo list
tea repo view <owner>/<repo>
tea issue list --repo <owner>/<repo> --state open
tea issue view <number> --repo <owner>/<repo>
tea pr list --repo <owner>/<repo> --state open
tea pr view <number> --repo <owner>/<repo>
```

Clone only for inspection, keep the clone under `/workspace`, then discard it.

```bash
git clone <gitea-url>/<owner>/<repo> /workspace/<repo>
cd /workspace/<repo>
git ls-tree -r HEAD --name-only
git show HEAD:path/to/file.yaml
git show <sha>:path/to/file.yaml
git log --oneline -20
git log --oneline -- path/to/file.yaml
git show <sha> --stat
```

## Rules

- Do not push branches, open pull requests, create commits, merge, or modify repo state.
- Do not stage or commit changes.
- The Gitea admin account `__GITEA_ADMIN_USERNAME__` remains the final authority for approvals and merges on protected `main`.
- Cite concrete repo paths, commits, issues, or PRs when they shape a design.
- Tell main when a design depends on absent, ambiguous, or inconsistent Gitea state.
- If plain `tea` fails, one retry with `--login "$REVIEWER_GITEA_TEA_LOGIN_NAME"` is acceptable to confirm a login-selection problem before you report the blocker.
- If `tea` auth fails or a critical repo is missing, stop and tell main exactly what failed.
