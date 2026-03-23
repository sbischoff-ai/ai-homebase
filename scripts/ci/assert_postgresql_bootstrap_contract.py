#!/usr/bin/env python3
"""Static assertions for chart-managed shared PostgreSQL bootstrap."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys

BASE_VALUES = "charts/platform-stack/values.yaml"
K3D_VALUES = "charts/platform-stack/values-k3d.yaml"


def require(text: str, needle: str, *, context: str) -> None:
    if needle not in text:
        raise SystemExit(f"{context} is missing expected text: {needle!r}")


def forbid(text: str, needle: str, *, context: str) -> None:
    if needle in text:
        raise SystemExit(f"{context} still contains legacy text: {needle!r}")


def render(*values_files: str, set_values: dict[str, str] | None = None) -> str:
    cmd = ["helm", "template", "platform-stack", "charts/platform-stack"]
    for values_file in values_files:
        cmd.extend(["-f", values_file])
    for key, value in (set_values or {}).items():
        cmd.extend(["--set", f"{key}={value}"])
    try:
        return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout
    except subprocess.CalledProcessError as exc:
        detail = (exc.stderr or exc.stdout or "").strip()
        raise SystemExit(f"failed to render chart-managed PostgreSQL bootstrap contract: {detail}") from exc


def main() -> None:
    platform_values = Path("charts/platform-stack/values.yaml").read_text()
    bootstrap_template = Path("charts/platform-stack/templates/shared-postgresql-bootstrap-job.yaml").read_text()
    bootstrap_script = Path("scripts/k3d-bootstrap-secrets.sh").read_text()
    vaultwarden_template = Path("charts/vaultwarden/templates/deployment.yaml").read_text()
    gitea_values = Path("charts/gitea/values.yaml").read_text()

    require(platform_values, "bootstrap:", context="charts/platform-stack/values.yaml")
    require(platform_values, 'tag: "17.5-alpine"', context="charts/platform-stack/values.yaml")
    require(platform_values, 'scriptsSecret: ""', context="charts/platform-stack/values.yaml")
    require(gitea_values, "preExtraInitContainers:", context="charts/gitea/values.yaml")
    require(gitea_values, "wait-for-shared-postgresql-bootstrap", context="charts/gitea/values.yaml")
    require(vaultwarden_template, "wait-for-shared-postgresql-bootstrap", context="charts/vaultwarden/templates/deployment.yaml")
    require(vaultwarden_template, "key: VAULTWARDEN_DB_PASSWORD", context="charts/vaultwarden/templates/deployment.yaml")

    require(bootstrap_template, "kind: Job", context="charts/platform-stack/templates/shared-postgresql-bootstrap-job.yaml")
    require(bootstrap_template, 'rolname = \'gitea\'', context="charts/platform-stack/templates/shared-postgresql-bootstrap-job.yaml")
    require(bootstrap_template, 'rolname = \'vaultwarden\'', context="charts/platform-stack/templates/shared-postgresql-bootstrap-job.yaml")
    require(bootstrap_template, "CREATE DATABASE gitea OWNER gitea", context="charts/platform-stack/templates/shared-postgresql-bootstrap-job.yaml")
    require(bootstrap_template, "CREATE DATABASE vaultwarden OWNER vaultwarden", context="charts/platform-stack/templates/shared-postgresql-bootstrap-job.yaml")
    require(bootstrap_template, 'key: GITEA__database__PASSWD', context="charts/platform-stack/templates/shared-postgresql-bootstrap-job.yaml")
    require(bootstrap_template, 'key: VAULTWARDEN_DB_PASSWORD', context="charts/platform-stack/templates/shared-postgresql-bootstrap-job.yaml")
    require(bootstrap_template, 'restartPolicy: Never', context="charts/platform-stack/templates/shared-postgresql-bootstrap-job.yaml")
    require(bootstrap_template, 'terminationMessagePolicy: FallbackToLogsOnError', context="charts/platform-stack/templates/shared-postgresql-bootstrap-job.yaml")

    forbid(bootstrap_script, "create_and_apply_secret shared-postgresql-initdb", context="scripts/k3d-bootstrap-secrets.sh")
    forbid(bootstrap_script, "reconcile_gitea_postgres_live", context="scripts/k3d-bootstrap-secrets.sh")
    require(bootstrap_script, 'jsonpath=\'{.data.VAULTWARDEN_DB_PASSWORD}\'', context="scripts/k3d-bootstrap-secrets.sh")
    require(bootstrap_script, '--from-literal=VAULTWARDEN_DB_PASSWORD="${VAULTWARDEN_DB_PASSWORD}"', context="scripts/k3d-bootstrap-secrets.sh")

    rendered_disabled = render(BASE_VALUES, set_values={"gitea.enabled": "false", "vaultwarden.enabled": "false"})
    if "platform-stack-shared-postgresql-bootstrap" in rendered_disabled:
        raise SystemExit("render unexpectedly included shared PostgreSQL bootstrap Job with both dependent services disabled")

    rendered_k3d = render(BASE_VALUES, K3D_VALUES)
    require(rendered_k3d, "kind: Job", context="rendered k3d manifests")
    require(rendered_k3d, "name: platform-stack-shared-postgresql-bootstrap", context="rendered k3d manifests")
    require(rendered_k3d, "wait-for-shared-postgresql-bootstrap", context="rendered k3d manifests")
    require(rendered_k3d, "VAULTWARDEN_DB_PASSWORD", context="rendered k3d manifests")
    require(rendered_k3d, "restartPolicy: Never", context="rendered k3d manifests")
    require(rendered_k3d, "terminationMessagePolicy: FallbackToLogsOnError", context="rendered k3d manifests")

    print("shared PostgreSQL bootstrap contract: chart-managed job + workload waits are aligned")


if __name__ == "__main__":
    main()
