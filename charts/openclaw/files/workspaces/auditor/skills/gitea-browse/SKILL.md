---
name: gitea-browse
description: Review in-cluster Gitea repos and pull requests by reading files, inspecting diffs, checking comments, posting review feedback, and approving with the shared reviewer identity; merge only with explicit instruction.
---

# Gitea Review Browse

Use this skill to inspect in-cluster source control and conduct PR-level audit review.
Your gateway runtime is expected to have the shared reviewer identity already configured for `git` and `tea`.

## Default Repos

- `cluster-gitops` - GitOps deployment definitions, platform-stack charts, values, and cluster handoff material
- `openclaw-sandbox-images` - Dockerfiles and image build configs for agent sandbox runtimes

## Review Commands

Use `git` and `tea` with the shared reviewer identity that is already configured in your runtime.

```bash
tea repo list
tea repo view <owner>/<repo>
tea pr list --repo <owner>/<repo> --state open
tea pr view <number> --repo <owner>/<repo>
tea issue list --repo <owner>/<repo> --state open
tea issue view <number> --repo <owner>/<repo>
tea pr reviews <number> --repo <owner>/<repo>
```

Clone only for review inspection, then discard the clone.

```bash
git clone <gitea-url>/<owner>/<repo> /tmp/<repo>
cd /tmp/<repo>
git show <sha>:path/to/file.yaml
git show <sha>
git diff <expected-sha>..<actual-sha> -- path/to/file
git fetch origin pull/<number>/head:pr-<number>
git diff main..pr-<number>
```

## PR Actions

```bash
tea pr review <number> --repo <owner>/<repo> --comment "Your review observation"
tea pr review <number> --repo <owner>/<repo> --approve
tea pr merge <number> --repo <owner>/<repo>
```

## Rules

- PR comments and approvals are permitted when they are part of the requested audit.
- Merge only when main or the user explicitly instructs you to merge.
- Do not push branches, create commits, or modify repo file content directly.
- Ground audit reports in specific commits, file paths, diff hunks, issues, or PR comments.
- Flag discrepancies between Gitea state and approved designs to main.
- If `tea` auth fails, a PR is out of scope, or a merge conflicts, stop and tell main exactly what failed.
