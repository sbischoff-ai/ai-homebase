#!/usr/bin/env python3
"""Static assertions for the Gitea env-backed config contract."""

from __future__ import annotations

from pathlib import Path
import re


def require(text: str, needle: str, *, context: str) -> None:
    if needle not in text:
        raise SystemExit(f"{context} is missing expected text: {needle!r}")


def forbid(text: str, needle: str, *, context: str) -> None:
    if needle in text:
        raise SystemExit(f"{context} still contains legacy text: {needle!r}")


def main() -> None:
    wrapper_values = Path("charts/gitea/values.yaml").read_text()
    platform_values = Path("charts/platform-stack/values.yaml").read_text()
    bootstrap_script = Path("scripts/bootstrap-secrets.sh").read_text()

    for name, text in (
        ("charts/gitea/values.yaml", wrapper_values),
        ("charts/platform-stack/values.yaml", platform_values),
    ):
        require(text, "preExtraInitContainers:", context=name)
        require(text, "wait-for-shared-postgresql-bootstrap", context=name)
        require(text, "additionalConfigFromEnvs:", context=name)
        require(text, "name: GITEA__database__PASSWD", context=name)
        require(text, "name: GITEA__session__PROVIDER_CONFIG", context=name)
        require(text, "name: GITEA__cache__HOST", context=name)
        require(text, "name: GITEA__queue__CONN_STR", context=name)
        require(text, "name: GITEA__global_lock__SERVICE_CONN_STR", context=name)
        require(text, "name: gitea-config-secrets", context=name)
        require(text, "additionalConfigSources: []", context=name)
        if not re.search(r"\bvalkey:\n\s+enabled: false", text):
            raise SystemExit(f"{name} is missing disabled valkey configuration")
        if not re.search(r"\bvalkey-cluster:\n\s+enabled: false", text):
            raise SystemExit(f"{name} is missing disabled valkey-cluster configuration")
        forbid(text, "redis-cluster:", context=name)
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
            context="scripts/bootstrap-secrets.sh",
        )

    require(
        bootstrap_script,
        'gitea-config-secrets',
        context="scripts/bootstrap-secrets.sh",
    )
    require(
        bootstrap_script,
        "resolve_from_existing_secret_or_generate \"$GITEA_DB_PASSWORD\" gitea-config-secrets '{.data.GITEA__database__PASSWD}'",
        context="scripts/bootstrap-secrets.sh",
    )
    require(
        bootstrap_script,
        'create_and_apply_secret gitea-admin-secret',
        context="scripts/bootstrap-secrets.sh",
    )
    forbid(
        bootstrap_script,
        'create_and_apply_secret shared-postgresql-initdb',
        context="scripts/bootstrap-secrets.sh",
    )
    forbid(
        bootstrap_script,
        'reconcile_gitea_postgres_live',
        context="scripts/bootstrap-secrets.sh",
    )

    if re.search(r'--from-literal=(?:database|session|cache|queue|global_lock)=', bootstrap_script):
        raise SystemExit(
            "scripts/bootstrap-secrets.sh still writes legacy section-style Gitea config keys"
        )

    print("gitea config contract: env-backed secret refs are aligned")


if __name__ == "__main__":
    main()
