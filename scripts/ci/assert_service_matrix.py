#!/usr/bin/env python3
"""Render service toggle matrix and assert key resources are present."""

from __future__ import annotations

import subprocess

import yaml

LEGACY_GITEA_WRAPPER_SOURCES = {
    "# Source: platform-stack/charts/gitea/templates/statefulset.yaml",
    "# Source: platform-stack/charts/gitea/templates/service.yaml",
    "# Source: platform-stack/charts/gitea/templates/ingress.yaml",
    "# Source: platform-stack/charts/gitea/templates/pvc.yaml",
}

MATRIX = [
    {
        "name": "core-only",
        "set": {
            "nextcloud.enabled": "false",
            "gitea.enabled": "false",
            "paperlessNgx.enabled": "false",
            "infisical.enabled": "false",
            "wgEasy.enabled": "false",
        },
        "expect_present": {
            ("Deployment", "platform-stack-openclaw"),
            ("Deployment", "platform-stack-openhands"),
        },
    },
    {
        "name": "core-plus-storage-heavy",
        "set": {
            "nextcloud.enabled": "true",
            "gitea.enabled": "true",
            "paperlessNgx.enabled": "true",
            "infisical.enabled": "false",
            "wgEasy.enabled": "false",
        },
        "expect_present": {
            ("StatefulSet", "platform-stack-nextcloud"),
            ("StatefulSet", "platform-stack-paperless-ngx"),
        },
    },
    {
        "name": "all-services-enabled",
        "set": {
            "nextcloud.enabled": "true",
            "gitea.enabled": "true",
            "paperlessNgx.enabled": "true",
            "infisical.enabled": "true",
            "wgEasy.enabled": "true",
        },
        "expect_present": {
            ("Deployment", "platform-stack-infisical"),
            ("Deployment", "platform-stack-wg-easy"),
            ("StatefulSet", "platform-stack-nextcloud"),
            ("StatefulSet", "platform-stack-paperless-ngx"),
        },
    },
]


def render(case: dict[str, object]) -> tuple[str, set[tuple[str | None, str | None]]]:
    cmd = [
        "helm",
        "template",
        "platform-stack",
        "charts/platform-stack",
        "-f",
        "charts/platform-stack/values.yaml",
    ]
    for key, value in case["set"].items():
        cmd.extend(["--set", f"{key}={value}"])

    result = subprocess.run(cmd, check=True, capture_output=True, text=True)
    docs = [doc for doc in yaml.safe_load_all(result.stdout) if isinstance(doc, dict)]
    resources = {(doc.get("kind"), doc.get("metadata", {}).get("name")) for doc in docs}
    return result.stdout, resources


def assert_gitea_single_path(case: dict[str, object], rendered: str, resources: set[tuple[str | None, str | None]]) -> None:
    gitea_enabled = case["set"].get("gitea.enabled") == "true"
    if not gitea_enabled:
        return

    legacy_sources = sorted(source for source in LEGACY_GITEA_WRAPPER_SOURCES if source in rendered)
    if legacy_sources:
        raise SystemExit(
            f"{case['name']} still renders removed local gitea wrapper templates: {legacy_sources}"
        )

    workload_kinds = {"StatefulSet", "Deployment"}
    workload_count = sum(
        1
        for kind, name in resources
        if name == "platform-stack-gitea" and kind in workload_kinds
    )
    if workload_count > 1:
        raise SystemExit(
            f"{case['name']} rendered multiple gitea workloads for platform-stack-gitea: {workload_count}"
        )


def main() -> None:
    for case in MATRIX:
        rendered, resources = render(case)
        missing = sorted(case["expect_present"] - resources)
        if missing:
            raise SystemExit(f"{case['name']} missing expected resources: {missing}")
        assert_gitea_single_path(case, rendered, resources)
        print(f"{case['name']}: asserted {len(case['expect_present'])} resource(s)")


if __name__ == "__main__":
    main()
