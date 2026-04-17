#!/usr/bin/env python3
from __future__ import annotations

import re
import subprocess
import sys
import tempfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]

REQUIRED_BOOTSTRAP_FILES = {
    "decisions.md",
    "automation-backlog.md",
    "watchdog-status-log.md",
    "audit-reports/README.md",
}


def fail(message: str) -> None:
    raise SystemExit(message)


def read_text(relative_path: str) -> str:
    return (REPO_ROOT / relative_path).read_text()


def assert_bootstrap_content_seeded() -> None:
    values_text = read_text("charts/platform-stack/values.yaml")
    config_text = read_text("scripts/bootstrap-config.py")

    values_paths = set(re.findall(r"- path: ([^\n]+)", values_text))
    config_paths = set(re.findall(r'"([^"]+)"', re.search(r"NEXTCLOUD_PROJECT_BOOTSTRAP_FILES = \[(.*?)\]", config_text, re.S).group(1)))

    missing_in_values = sorted(REQUIRED_BOOTSTRAP_FILES - values_paths)
    missing_in_config = sorted(REQUIRED_BOOTSTRAP_FILES - config_paths)
    if missing_in_values:
        fail(f"charts/platform-stack/values.yaml is missing seeded ai-homebase bootstrap paths: {', '.join(missing_in_values)}")
    if missing_in_config:
        fail(f"scripts/bootstrap-config.py is missing NEXTCLOUD_PROJECT_BOOTSTRAP_FILES entries: {', '.join(missing_in_config)}")

    for relative in REQUIRED_BOOTSTRAP_FILES:
        path = REPO_ROOT / "charts/platform-stack/files/bootstrap-content/ai-homebase/projects" / relative
        if not path.exists():
            fail(f"bootstrap content file is missing from charts/platform-stack/files/bootstrap-content/ai-homebase/projects: {relative}")


def assert_cron_skill_refs_valid() -> None:
    skill_names = set()
    for skill_file in (REPO_ROOT / "charts/openclaw/files/workspaces").glob("**/SKILL.md"):
        text = skill_file.read_text()
        match = re.search(r"^name:\s*([a-z0-9-]+)\s*$", text, re.M)
        if match:
            skill_names.add(match.group(1))

    for cron_file in (REPO_ROOT / "scripts/cron-messages").glob("*.md"):
        text = cron_file.read_text()
        for match in re.finditer(r"Use the `([a-z0-9-]+)` skill", text):
            skill_name = match.group(1)
            if skill_name not in skill_names:
                fail(f"{cron_file.relative_to(REPO_ROOT)} references missing skill `{skill_name}`")


def assert_no_stale_main_model_claim() -> None:
    projects_dir = REPO_ROOT / "charts/platform-stack/files/bootstrap-content/ai-homebase/projects"
    for path in projects_dir.glob("*.md"):
        text = path.read_text()
        if "GPT-4.1" in text:
            fail(f"{path.relative_to(REPO_ROOT)} still contains stale GPT-4.1 model text")


def assert_reviewer_wiring_present() -> None:
    required_snippets = {
        "bootstrap.example.toml": ["[openclaw.agents.reviewer.gitea]"],
        "scripts/bootstrap-config.py": [
            "REVIEWER_GITEA_USERNAME",
            "REVIEWER_GITEA_PASSWORD",
            "REVIEWER_GITEA_TOKEN",
            "reviewer-gitea-init.sh",
            "CODER_GITEA_TOKEN",
        ],
        "scripts/bootstrap-secrets.sh": [
            "reviewer-credentials",
            "REVIEWER_GITEA_PASSWORD",
            "REVIEWER_GITEA_TOKEN",
            "CODER_GITEA_TOKEN",
        ],
        "scripts/bootstrap-gitops.sh": [
            "REVIEWER_GITEA_USERNAME",
            "REVIEWER_GITEA_TOKEN",
            "CODER_GITEA_TOKEN",
            "branch_protections",
            "collaborators",
        ],
        "charts/platform-stack/values.yaml": [
            "reviewer-credentials",
            "REVIEWER_GITEA_PASSWORD",
            "REVIEWER_GITEA_TOKEN",
            "CODER_GITEA_TOKEN",
            "reviewer-gitea-init.sh",
        ],
        "charts/openclaw/values.yaml": [
            "reviewer-credentials",
            "REVIEWER_GITEA_PASSWORD",
            "REVIEWER_GITEA_TOKEN",
            "CODER_GITEA_TOKEN",
            "reviewer-gitea-init.sh",
        ],
        "scripts/bootstrap-openclaw-skills.sh": ["reviewer-gitea-init.sh"],
    }
    for relative_path, snippets in required_snippets.items():
        text = read_text(relative_path)
        for snippet in snippets:
            if snippet not in text:
                fail(f"{relative_path} is missing reviewer wiring snippet: {snippet}")


def run_python_script(relative_path: str, *args: str) -> None:
    subprocess.run(
        [sys.executable, str(REPO_ROOT / relative_path), *args],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    )


def assert_rendered_repo_agents_contracts() -> None:
    with tempfile.TemporaryDirectory(prefix="ai-homebase-rendered-gitops-") as tmpdir:
        output_dir = Path(tmpdir) / "cluster-gitops"
        run_python_script(
            "scripts/render-gitops-repo.py",
            "--output-dir",
            str(output_dir),
            "--bootstrap-config",
            str(REPO_ROOT / "bootstrap.example.toml"),
            "--profile",
            "k3d",
            "--cluster-name",
            "contract-test",
            "--release-name",
            "platform-stack",
            "--namespace",
            "ai-homebase",
            "--repo-url",
            "http://example.invalid/coder/cluster-gitops.git",
            "--repo-branch",
            "main",
            "--project",
            "platform-stack",
        )
        agents_text = (output_dir / "AGENTS.md").read_text()
        required_snippets = [
            "gitops/clusters/contract-test/applications/platform-stack.yaml",
            "values-k3d.yaml",
            "helm lint charts/platform-stack",
            "helm template platform-stack charts/platform-stack",
        ]
        forbidden_snippets = [
            "./scripts/lint.sh",
            "./scripts/template.sh",
        ]
        for snippet in required_snippets:
            if snippet not in agents_text:
                fail(f"rendered cluster-gitops AGENTS.md is missing required snippet: {snippet}")
        for snippet in forbidden_snippets:
            if snippet in agents_text:
                fail(f"rendered cluster-gitops AGENTS.md still contains forbidden snippet: {snippet}")

    with tempfile.TemporaryDirectory(prefix="ai-homebase-rendered-sandbox-images-") as tmpdir:
        output_dir = Path(tmpdir) / "openclaw-sandbox-images"
        run_python_script(
            "scripts/render-sandbox-images-repo.py",
            "--output-dir",
            str(output_dir),
            "--registry-host",
            "registry.example.invalid",
            "--repo-owner",
            "coder",
            "--gitops-repo-name",
            "cluster-gitops",
        )
        agents_text = (output_dir / "AGENTS.md").read_text()
        required_snippets = [
            "scripts/build-openclaw-sandbox-images.sh",
            "scripts/openclaw-remote-docker-publish-images.sh",
            "Do not mutate `cluster-gitops` from inside this repo.",
        ]
        for snippet in required_snippets:
            if snippet not in agents_text:
                fail(f"rendered openclaw-sandbox-images AGENTS.md is missing required snippet: {snippet}")


def assert_coder_skill_defers_to_repo_agents() -> None:
    skill_text = read_text("charts/openclaw/files/workspaces/coder/skills/manage-gitea-gitops-and-registry/SKILL.md")
    required_snippets = [
        "start Codex from the target repo root under `/workspace`",
    ]
    forbidden_snippets = [
        "./scripts/lint.sh",
        "./scripts/template.sh",
        "If the target repo is `ai-homebase`",
        "AGENTS.md",
    ]
    for snippet in required_snippets:
        if snippet not in skill_text:
            fail(f"coder Gitea/GitOps skill is missing required repo-local guidance: {snippet}")
    for snippet in forbidden_snippets:
        if snippet in skill_text:
            fail(f"coder Gitea/GitOps skill still contains forbidden maintainer-context snippet: {snippet}")


def main() -> int:
    assert_bootstrap_content_seeded()
    assert_cron_skill_refs_valid()
    assert_no_stale_main_model_claim()
    assert_reviewer_wiring_present()
    assert_rendered_repo_agents_contracts()
    assert_coder_skill_defers_to_repo_agents()
    print("OpenClaw agent contract assertions passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
