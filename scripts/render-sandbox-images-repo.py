#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]

INCLUDED_PATHS = (
    Path("images/openclaw-sandbox-base/Dockerfile"),
    Path("images/openclaw-sandbox-base/reviewer-gitea-init.sh"),
    Path("images/openclaw-sandbox-coder/Dockerfile"),
    Path("images/openclaw-sandbox-coder/coder-init.sh"),
    Path("images/gitea-actions-job/Dockerfile"),
    Path("images/openclaw-remote-docker/Dockerfile"),
    Path("images/openclaw-remote-docker/openclaw-gateway-start.sh"),
    Path("images/openclaw-remote-docker/reviewer-gitea-init.sh"),
    Path("scripts/build-openclaw-sandbox-images.sh"),
    Path("scripts/openclaw-remote-docker-load-images.sh"),
    Path("scripts/openclaw-remote-docker-publish-images.sh"),
)


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def copy_path(relative_path: Path, output_dir: Path) -> None:
    source = REPO_ROOT / relative_path
    target = output_dir / relative_path
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


def render_readme(registry_host: str, repo_owner: str, gitops_repo_name: str) -> str:
    return f"""# OpenClaw Sandbox Images

This repository is the canonical source for the OpenClaw sandbox runtime images used by ai-homebase.

Images owned here:
- `openclaw-sandbox`
- `openclaw-sandbox-coder`
- `gitea-actions-job`
- `openclaw-remote-docker`

Operating model:
- commit sandbox-image source changes here first;
- build the images with `scripts/build-openclaw-sandbox-images.sh`;
- publish canonical runtime tags to the in-cluster registry;
- update `{gitops_repo_name}` only after the new registry tags exist.

Default registry namespace:
- registry host: `{registry_host}`
- namespace: `{repo_owner}`

Canonical image names:
- `{registry_host}/{repo_owner}/openclaw-sandbox:trixie-slim`
- `{registry_host}/{repo_owner}/openclaw-sandbox-coder:trixie-slim`
- `{registry_host}/{repo_owner}/gitea-actions-job:trixie-slim`
- `{registry_host}/{repo_owner}/openclaw-remote-docker:trixie-slim`
"""


def render_agents_md(registry_host: str, repo_owner: str, gitops_repo_name: str) -> str:
    return f"""# AGENTS.md

This repository is the source of truth for OpenClaw runtime image source.

## First Steps

- Read this file first.
- Keep work inside this repo and follow the committed Dockerfiles, helper scripts, and README.
- Keep the normal shared-repo posture: branch first, then open a pull request against protected `main`.

## Validation And Build

- Use `scripts/build-openclaw-sandbox-images.sh` for standard validation and build work in this repo.
- Treat changes to Dockerfiles and init scripts as image-affecting.
- Build the affected images before changing image references elsewhere.
- Keep canonical image naming aligned with the README and the expected registry namespace `{registry_host}/{repo_owner}`.

## Publish And Coordination

- Publish canonical tags only when the task explicitly includes release or coordinated rollout work.
- When publish work is required, follow the repo scripts and README, including `scripts/openclaw-remote-docker-publish-images.sh` for the remote Docker publish path.
- Do not mutate `{gitops_repo_name}` from inside this repo. Cross-repo coordination happens through coder, with GitOps reference updates handled in the separate repo.
"""


def main() -> int:
    parser = argparse.ArgumentParser(description="Render a slim sandbox-images repo snapshot")
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--registry-host", required=True)
    parser.add_argument("--repo-owner", required=True)
    parser.add_argument("--gitops-repo-name", required=True)
    args = parser.parse_args()

    if args.output_dir.exists():
        shutil.rmtree(args.output_dir)

    for path in INCLUDED_PATHS:
        copy_path(path, args.output_dir)

    write_text(
        args.output_dir / "AGENTS.md",
        render_agents_md(args.registry_host, args.repo_owner, args.gitops_repo_name),
    )
    write_text(
        args.output_dir / "README.md",
        render_readme(args.registry_host, args.repo_owner, args.gitops_repo_name),
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
