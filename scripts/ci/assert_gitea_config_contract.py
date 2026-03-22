#!/usr/bin/env python3
"""Static assertions for the Gitea secret-backed config contract."""

from __future__ import annotations

from pathlib import Path
import re
import sys


def require(text: str, needle: str, *, context: str) -> None:
    if needle not in text:
        raise SystemExit(f"{context} is missing expected text: {needle!r}")


def forbid(text: str, needle: str, *, context: str) -> None:
    if needle in text:
        raise SystemExit(f"{context} still contains legacy text: {needle!r}")


def main() -> None:
    wrapper_values = Path("charts/gitea/values.yaml").read_text()
    platform_values = Path("charts/platform-stack/values.yaml").read_text()
    bootstrap_script = Path("scripts/k3d-bootstrap-secrets.sh").read_text()

    for name, text in (
        ("charts/gitea/values.yaml", wrapper_values),
        ("charts/platform-stack/values.yaml", platform_values),
    ):
        require(text, "additionalConfigFromEnvs: []", context=name)
        require(text, "additionalConfigSources:", context=name)
        require(text, "secretName: gitea-config-secrets", context=name)
        forbid(text, "GITEA__database__PASSWD", context=name)
        forbid(text, "GITEA__session__PROVIDER_CONFIG", context=name)
        forbid(text, "GITEA__cache__HOST", context=name)
        forbid(text, "GITEA__queue__CONN_STR", context=name)
        forbid(text, "GITEA__global_lock__SERVICE_CONN_STR", context=name)

    for key in ("database", "session", "cache", "queue", "global_lock"):
        require(
            bootstrap_script,
            f'--from-literal={key}=',
            context="scripts/k3d-bootstrap-secrets.sh",
        )

    for section_key in (
        "PASSWD=",
        "PROVIDER_CONFIG=",
        "HOST=",
        "CONN_STR=",
        "SERVICE_CONN_STR=",
    ):
        require(
            bootstrap_script,
            section_key,
            context="scripts/k3d-bootstrap-secrets.sh",
        )

    if re.search(r"GITEA__(?:database|session|cache|queue|global_lock)__", bootstrap_script):
        raise SystemExit(
            "scripts/k3d-bootstrap-secrets.sh still writes legacy env-style Gitea config keys"
        )

    print("gitea config contract: secret-backed config sources are aligned")


if __name__ == "__main__":
    main()
