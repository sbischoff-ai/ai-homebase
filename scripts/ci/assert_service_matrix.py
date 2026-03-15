#!/usr/bin/env python3
from __future__ import annotations

import subprocess

import yaml

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
            ("StatefulSet", "platform-stack-gitea"),
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
            ("StatefulSet", "platform-stack-gitea"),
            ("StatefulSet", "platform-stack-paperless-ngx"),
        },
    },
]


def render(case: dict[str, object]) -> set[tuple[str | None, str | None]]:
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
    return {(doc.get("kind"), doc.get("metadata", {}).get("name")) for doc in docs}


def main() -> None:
    for case in MATRIX:
        resources = render(case)
        missing = sorted(case["expect_present"] - resources)
        if missing:
            raise SystemExit(f"{case['name']} missing expected resources: {missing}")
        print(f"{case['name']}: asserted {len(case['expect_present'])} resource(s)")


if __name__ == "__main__":
    main()
