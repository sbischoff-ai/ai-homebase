#!/usr/bin/env python3
"""Static assertions for the Gitea env-backed config contract."""

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
        require(text, "additionalConfigFromEnvs:", context=name)
        require(text, "name: GITEA__database__PASSWD", context=name)
        require(text, "name: GITEA__session__PROVIDER_CONFIG", context=name)
        require(text, "name: GITEA__cache__HOST", context=name)
        require(text, "name: GITEA__queue__CONN_STR", context=name)
        require(text, "name: GITEA__global_lock__SERVICE_CONN_STR", context=name)
        require(text, "name: gitea-config-secrets", context=name)
        require(text, "additionalConfigSources: []", context=name)
        forbid(text, "secretName: gitea-config-secrets", context=name)

    for key in (
        "GITEA__database__PASSWD",
        "GITEA__session__PROVIDER_CONFIG",
        "GITEA__cache__HOST",
        "GITEA__queue__CONN_STR",
        "GITEA__global_lock__SERVICE_CONN_STR",
    ):
        require(
            bootstrap_script,
            f'--from-literal={key}=',
            context="scripts/k3d-bootstrap-secrets.sh",
        )

    if re.search(r'--from-literal=(?:database|session|cache|queue|global_lock)=', bootstrap_script):
        raise SystemExit(
            "scripts/k3d-bootstrap-secrets.sh still writes legacy section-style Gitea config keys"
        )

    print("gitea config contract: env-backed secret refs are aligned")


if __name__ == "__main__":
    main()
