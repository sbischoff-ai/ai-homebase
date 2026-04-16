---
name: gitea-browse
description: Browse in-cluster Gitea repos, issues, pull requests, commits, chart values, GitOps definitions, and sandbox image sources for read-only design context with the shared reviewer identity.
---

# Gitea Browse

Use this skill to inspect in-cluster source control before design work.
Your sandbox is expected to arrive with the shared reviewer identity already configured for `git` and `tea`.

## Default Repos

- `cluster-gitops` - GitOps deployment definitions, platform-stack charts, values, and cluster handoff material
- `openclaw-sandbox-images` - Dockerfiles and image build configs for agent sandbox runtimes

## Read-Only Commands

Use `git` and `tea` with the shared reviewer identity that is already configured in your sandbox.

```bash
tea repo list
tea repo view <owner>/<repo>
tea issue list --repo <owner>/<repo> --state open
tea issue view <number> --repo <owner>/<repo>
tea pr list --repo <owner>/<repo> --state open
tea pr view <number> --repo <owner>/<repo>
```

Clone only for inspection, then discard the clone.

```bash
git clone <gitea-url>/<owner>/<repo> /tmp/<repo>
cd /tmp/<repo>
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
- Cite concrete repo paths, commits, issues, or PRs when they shape a design.
- Tell main when a design depends on absent, ambiguous, or inconsistent Gitea state.
- If `tea` auth fails or a critical repo is missing, stop and tell main exactly what failed.
