#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]

INCLUDED_PATHS = (
    Path("images/openclaw-sandbox-base/Dockerfile"),
    Path("images/openclaw-sandbox-coder/Dockerfile"),
    Path("images/openclaw-remote-docker/Dockerfile"),
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
- `{registry_host}/{repo_owner}/openclaw-sandbox:bookworm-slim`
- `{registry_host}/{repo_owner}/openclaw-sandbox-coder:bookworm-slim`
- `{registry_host}/{repo_owner}/openclaw-remote-docker:bookworm-slim`
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
        args.output_dir / "README.md",
        render_readme(args.registry_host, args.repo_owner, args.gitops_repo_name),
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
