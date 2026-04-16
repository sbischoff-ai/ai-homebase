#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
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
        "scripts/bootstrap-config.py": ["REVIEWER_GITEA_USERNAME", "REVIEWER_GITEA_PASSWORD", "reviewer-gitea-init.sh"],
        "scripts/bootstrap-secrets.sh": ["reviewer-credentials", "REVIEWER_GITEA_PASSWORD"],
        "scripts/bootstrap-gitops.sh": ["REVIEWER_GITEA_USERNAME", "branch_protections", "collaborators"],
        "charts/platform-stack/values.yaml": ["reviewer-credentials", "REVIEWER_GITEA_PASSWORD", "reviewer-gitea-init.sh"],
        "charts/openclaw/values.yaml": ["reviewer-credentials", "REVIEWER_GITEA_PASSWORD", "reviewer-gitea-init.sh"],
        "scripts/bootstrap-openclaw-skills.sh": ["reviewer-gitea-init.sh"],
    }
    for relative_path, snippets in required_snippets.items():
        text = read_text(relative_path)
        for snippet in snippets:
            if snippet not in text:
                fail(f"{relative_path} is missing reviewer wiring snippet: {snippet}")


def main() -> int:
    assert_bootstrap_content_seeded()
    assert_cron_skill_refs_valid()
    assert_no_stale_main_model_claim()
    assert_reviewer_wiring_present()
    print("OpenClaw agent contract assertions passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
