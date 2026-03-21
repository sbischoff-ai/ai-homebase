#!/usr/bin/env python3
"""Render platform-stack manifests for static assertions over service toggles and profile overlays."""

from __future__ import annotations

import re
import subprocess

LEGACY_CERT_MANAGER_PATTERN = re.compile(r"certManager[A-Z]")

BASE_VALUES = "charts/platform-stack/values.yaml"
K3D_VALUES = "charts/platform-stack/values-k3d.yaml"
K3S_VALUES = "charts/platform-stack/values-k3s.yaml"

CERT_MANAGER_EXPECTED_RESOURCES = {
    ("Deployment", "platform-stack-cert-manager"),
    ("Deployment", "platform-stack-cert-manager-cainjector"),
    ("Deployment", "platform-stack-cert-manager-webhook"),
}

K3D_GITEA_EXPECTED_RESOURCES = {
    ("Ingress", "platform-stack-gitea"),
    ("Service", "platform-stack-gitea-http"),
    ("Service", "platform-stack-gitea-ssh"),
    ("StatefulSet", "platform-stack-gitea"),
}

MATRIX = [
    {
        "name": "core-only",
        "set": {
            "nextcloud.enabled": "false",
            "gitea.enabled": "false",
            "paperlessNgx.enabled": "false",
            "infisical.enabled": "false",
        },
        "expect_present": {
            ("Deployment", "platform-stack-openclaw"),
            ("Ingress", "platform-stack-openclaw"),
        },
    },
    {
        "name": "core-plus-storage-heavy",
        "set": {
            "nextcloud.enabled": "true",
            "gitea.enabled": "true",
            "paperlessNgx.enabled": "true",
            "infisical.enabled": "false",
        },
        "expect_present": {
            ("Ingress", "platform-stack-openclaw"),
            ("StatefulSet", "platform-stack-nextcloud"),
            ("Ingress", "platform-stack-nextcloud"),
            ("StatefulSet", "platform-stack-paperless-ngx"),
            ("Ingress", "platform-stack-paperless-ngx"),
        },
    },
    {
        "name": "all-services-enabled",
        "set": {
            "nextcloud.enabled": "true",
            "gitea.enabled": "true",
            "paperlessNgx.enabled": "true",
            "infisical.enabled": "true",
        },
        "expect_present": {
            ("Ingress", "platform-stack-openclaw"),
            ("Deployment", "platform-stack-infisical"),
            ("Ingress", "infisical-ingress"),
            ("StatefulSet", "platform-stack-nextcloud"),
            ("Ingress", "platform-stack-nextcloud"),
            ("StatefulSet", "platform-stack-paperless-ngx"),
            ("Ingress", "platform-stack-paperless-ngx"),
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
    return [host.strip('"') for host in re.findall(r"^\s*(?:-\s+)?host:\s*([^\s]+)\s*$", doc, flags=re.MULTILINE)]


def ingress_class_name(doc: str) -> str | None:
    match = re.search(r"^\s*ingressClassName:\s*([^\s]+)\s*$", doc, flags=re.MULTILINE)
    return None if match is None else match.group(1).strip('"')


def assert_removed_platform_settings_configmap(resources: set[tuple[str | None, str | None]]) -> None:
    removed = ("ConfigMap", "platform-stack-platform-stack-settings")
    if removed in resources:
        raise SystemExit(
            "render unexpectedly includes removed umbrella settings ConfigMap platform-stack-platform-stack-settings"
        )


def assert_gitea_rendered_resources(profile_name: str, rendered: str, resources: set[tuple[str | None, str | None]]) -> None:
    missing = sorted(K3D_GITEA_EXPECTED_RESOURCES - resources)
    if missing:
        raise SystemExit(f"{profile_name} missing expected gitea resources: {missing}")

    ingress = find_document(rendered, kind="Ingress", name="platform-stack-gitea")
    if ingress is None:
        raise SystemExit(f"{profile_name} missing gitea ingress document")

    rendered_class_name = ingress_class_name(ingress)
    if rendered_class_name != "nginx":
        raise SystemExit(
            f"{profile_name} rendered gitea ingressClassName={rendered_class_name!r}, expected 'nginx'"
        )

    hosts = ingress_hosts(ingress)
    if "gitea.localtest.me" not in hosts:
        raise SystemExit(
            f"{profile_name} rendered gitea hosts={hosts!r}, expected to include 'gitea.localtest.me'"
        )


def assert_cert_manager_canonical(profile_name: str, rendered: str, resources: set[tuple[str | None, str | None]]) -> None:
    if LEGACY_CERT_MANAGER_PATTERN.search(rendered):
        raise SystemExit(f"{profile_name} rendered legacy cert-manager alias naming")

    missing = sorted(CERT_MANAGER_EXPECTED_RESOURCES - resources)
    if missing:
        raise SystemExit(f"{profile_name} missing canonical cert-manager resources: {missing}")

    for _, resource_name in resources:
        if resource_name is None:
            continue
        resource_name_lower = resource_name.lower()
        if ("cert-manager" in resource_name_lower or "certmanager" in resource_name_lower) and resource_name != resource_name_lower:
            raise SystemExit(
                f"{profile_name} rendered cert-manager resource name with uppercase characters: {resource_name}"
            )


def assert_k3d_default_ingress_classes() -> None:
    rendered = render_template(BASE_VALUES, K3D_VALUES)
    expected = {
        "platform-stack-openclaw": "openclaw.localtest.me",
        "infisical-ingress": "infisical.localtest.me",
    }
    for name, host in expected.items():
        ingress = find_document(rendered, kind="Ingress", name=name)
        if ingress is None:
            raise SystemExit(f"k3d overlay did not render ingress {name}")
        rendered_class_name = ingress_class_name(ingress)
        if rendered_class_name != "nginx":
            raise SystemExit(
                f"k3d overlay rendered {name} ingressClassName={rendered_class_name!r}, expected 'nginx'"
            )
        hosts = ingress_hosts(ingress)
        if host not in hosts:
            raise SystemExit(
                f"k3d overlay rendered {name} hosts={hosts!r}, expected to include {host!r}"
            )


def assert_k3d_gitea_overlay_render() -> None:
    rendered = render_template(BASE_VALUES, K3D_VALUES)
    resources = rendered_resources(rendered)
    assert_gitea_rendered_resources("k3d overlay", rendered, resources)


def main() -> None:
    for case in MATRIX:
        rendered = render_template(BASE_VALUES, set_values=case["set"])
        resources = rendered_resources(rendered)
        missing = sorted(case["expect_present"] - resources)
        if missing:
            raise SystemExit(f"{case['name']} missing expected resources: {missing}")
        assert_removed_platform_settings_configmap(resources)
        if case["set"].get("gitea.enabled") == "true":
            assert_gitea_rendered_resources(case["name"], rendered, resources)
        print(f"{case['name']}: asserted {len(case['expect_present'])} resource(s)")

    for profile_name, values_files in {
        "base": (BASE_VALUES,),
        "k3d": (BASE_VALUES, K3D_VALUES),
        "k3s": (BASE_VALUES, K3S_VALUES),
    }.items():
        rendered = render_template(*values_files)
        resources = rendered_resources(rendered)
        assert_cert_manager_canonical(profile_name, rendered, resources)
        print(f"{profile_name}: asserted canonical cert-manager naming")

    assert_k3d_default_ingress_classes()
    print("k3d overlay: asserted nginx ingressClassName + expected hosts for OpenClaw/Infisical")

    assert_k3d_gitea_overlay_render()
    print("k3d overlay: asserted gitea renders expected ingress, services, and workload")


if __name__ == "__main__":
    main()
