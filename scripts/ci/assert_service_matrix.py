#!/usr/bin/env python3
"""Render platform-stack manifests for static assertions over service toggles and profile overlays."""

from __future__ import annotations

import re
import subprocess

BASE_VALUES = "charts/platform-stack/values.yaml"
K3D_VALUES = "charts/platform-stack/values-k3d.yaml"

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


def render_template(*values_files: str, set_values: dict[str, str] | None = None) -> str:
    cmd = [
        "helm",
        "template",
        "platform-stack",
        "charts/platform-stack",
    ]
    for values_file in values_files:
        cmd.extend(["-f", values_file])
    for key, value in (set_values or {}).items():
        cmd.extend(["--set", f"{key}={value}"])

    return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout


def split_documents(rendered: str) -> list[str]:
    return [doc for doc in re.split(r"\n---\n", rendered) if doc.strip()]


def document_kind_name(doc: str) -> tuple[str | None, str | None]:
    kind = None
    name = None
    in_metadata = False

    for line in doc.splitlines():
        if kind is None and line.startswith("kind: "):
            kind = line.split(":", 1)[1].strip()
            continue

        if line == "metadata:":
            in_metadata = True
            continue

        if in_metadata:
            if line and not line.startswith("  "):
                in_metadata = False
                continue
            if line.startswith("  name: "):
                name = line.split(":", 1)[1].strip().strip('"')
                break

    return kind, name


def rendered_resources(rendered: str) -> set[tuple[str | None, str | None]]:
    return {document_kind_name(doc) for doc in split_documents(rendered)}


def find_document(rendered: str, *, kind: str, name: str) -> str | None:
    for doc in split_documents(rendered):
        doc_kind, doc_name = document_kind_name(doc)
        if doc_kind == kind and doc_name == name:
            return doc
    return None


def ingress_hosts(doc: str) -> list[str]:
    return [host.strip('"') for host in re.findall(r"^\s*- host:\s*([^\s]+)\s*$", doc, flags=re.MULTILINE)]


def ingress_class_name(doc: str) -> str | None:
    match = re.search(r"^\s*ingressClassName:\s*([^\s]+)\s*$", doc, flags=re.MULTILINE)
    return None if match is None else match.group(1).strip('"')


def assert_removed_platform_settings_configmap(resources: set[tuple[str | None, str | None]]) -> None:
    removed = ("ConfigMap", "platform-stack-platform-stack-settings")
    if removed in resources:
        raise SystemExit(
            "render unexpectedly includes removed umbrella settings ConfigMap platform-stack-platform-stack-settings"
        )


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
        for kind, resource_name in resources
        if resource_name == "platform-stack-gitea" and kind in workload_kinds
    )
    if workload_count > 1:
        raise SystemExit(
            f"{case['name']} rendered multiple gitea workloads for platform-stack-gitea: {workload_count}"
        )


def assert_k3d_wg_easy_ingress_class() -> None:
    rendered = render_template(BASE_VALUES, K3D_VALUES)
    ingress = find_document(rendered, kind="Ingress", name="platform-stack-wg-easy")
    if ingress is None:
        raise SystemExit("k3d overlay did not render the wg-easy Ingress")

    rendered_class_name = ingress_class_name(ingress)
    if rendered_class_name != "nginx":
        raise SystemExit(
            f"k3d overlay rendered wg-easy ingressClassName={rendered_class_name!r}, expected 'nginx'"
        )

    hosts = ingress_hosts(ingress)
    if "wg.localtest.me" not in hosts:
        raise SystemExit(
            f"k3d overlay rendered wg-easy hosts={hosts!r}, expected to include 'wg.localtest.me'"
        )


def main() -> None:
    for case in MATRIX:
        rendered = render_template(BASE_VALUES, set_values=case["set"])
        resources = rendered_resources(rendered)
        missing = sorted(case["expect_present"] - resources)
        if missing:
            raise SystemExit(f"{case['name']} missing expected resources: {missing}")
        assert_removed_platform_settings_configmap(resources)
        assert_gitea_single_path(case, rendered, resources)
        print(f"{case['name']}: asserted {len(case['expect_present'])} resource(s)")

    assert_k3d_wg_easy_ingress_class()
    print("k3d overlay: asserted wg-easy ingressClassName=nginx and host=wg.localtest.me")


if __name__ == "__main__":
    main()
