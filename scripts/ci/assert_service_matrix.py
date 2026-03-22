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

LEGACY_GITEA_WRAPPER_SOURCES = {
    "# Source: platform-stack/charts/gitea/templates/statefulset.yaml",
    "# Source: platform-stack/charts/gitea/templates/service.yaml",
    "# Source: platform-stack/charts/gitea/templates/ingress.yaml",
    "# Source: platform-stack/charts/gitea/templates/pvc.yaml",
}

DEPENDENCY_UPDATE_PATHS = (
    "charts/gitea",
    "charts/platform-stack",
)

_DEPENDENCIES_READY = False

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
    ensure_chart_dependencies()
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

    return run_command(cmd, context="failed to render Helm templates")


def ensure_chart_dependencies() -> None:
    global _DEPENDENCIES_READY
    if _DEPENDENCIES_READY:
        return

    for chart_path in DEPENDENCY_UPDATE_PATHS:
        run_command(
            ["helm", "dependency", "update", chart_path],
            context=f"failed to update Helm dependencies for {chart_path}",
        )

    _DEPENDENCIES_READY = True


def run_command(cmd: list[str], *, context: str) -> str:
    try:
        return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout
    except subprocess.CalledProcessError as exc:
        stderr = (exc.stderr or "").strip()
        stdout = (exc.stdout or "").strip()
        detail = stderr or stdout or f"command exited with status {exc.returncode}"
        raise SystemExit(f"{context}: {' '.join(cmd)}\n{detail}") from exc


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


def document_metadata_labels(doc: str) -> dict[str, str]:
    labels: dict[str, str] = {}
    in_metadata = False
    in_labels = False

    for line in doc.splitlines():
        if line == "metadata:":
            in_metadata = True
            in_labels = False
            continue

        if in_metadata and line and not line.startswith("  "):
            break

        if not in_metadata:
            continue

        if line == "  labels:":
            in_labels = True
            continue

        if in_labels:
            if line and not line.startswith("    "):
                in_labels = False
                continue
            if line.startswith("    ") and ":" in line:
                key, value = line.strip().split(":", 1)
                labels[key.strip()] = value.strip().strip('"')

    return labels


def document_source(doc: str) -> str | None:
    match = re.search(r"^# Source:\s*(.+)$", doc, re.MULTILINE)
    return None if match is None else match.group(1).strip()


def rendered_resources(rendered: str) -> set[tuple[str | None, str | None]]:
    return {document_kind_name(doc) for doc in split_documents(rendered)}


def docs_with_labels(rendered: str, *, kind: str | None = None) -> list[tuple[str, dict[str, str]]]:
    docs: list[tuple[str, dict[str, str]]] = []
    for doc in split_documents(rendered):
        doc_kind, _ = document_kind_name(doc)
        if kind is not None and doc_kind != kind:
            continue
        docs.append((doc, document_metadata_labels(doc)))
    return docs


def gitea_rendered_docs(rendered: str, *, kind: str | None = None) -> list[str]:
    matches: list[str] = []
    for doc, labels in docs_with_labels(rendered, kind=kind):
        source = document_source(doc) or ""
        if "charts/gitea/charts/gitea/templates/gitea/" in source or "charts/gitea/templates/gitea/" in source:
            matches.append(doc)
            continue
        _, resource_name = document_kind_name(doc)
        if resource_name is not None and "platform-stack-gitea" in resource_name:
            matches.append(doc)
            continue
        if labels.get("app.kubernetes.io/instance") != "platform-stack":
            continue
        if labels.get("app.kubernetes.io/name") != "gitea":
            continue
        matches.append(doc)
    return matches


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


def has_local_path_5gi_persistence(doc: str) -> bool:
    storage_class_patterns = (
        r"^\s*storageClassName:\s*['\"]?local-path['\"]?\s*$",
        r"^\s*storageClass:\s*['\"]?local-path['\"]?\s*$",
    )
    has_storage_class = any(re.search(pattern, doc, flags=re.MULTILINE) for pattern in storage_class_patterns)
    has_storage_request = re.search(r"^\s*storage:\s*['\"]?5Gi['\"]?\s*$", doc, flags=re.MULTILINE) is not None
    return has_storage_class and has_storage_request


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

    workload_kinds = ("StatefulSet", "Deployment")
    workload_count = sum(len(gitea_rendered_docs(rendered, kind=kind)) for kind in workload_kinds)
    if workload_count == 0:
        raise SystemExit(f"{case['name']} rendered no gitea workload resources")
    if workload_count > 1:
        raise SystemExit(
            f"{case['name']} rendered multiple gitea workloads: {workload_count}"
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


def assert_k3d_gitea_overlay_resources() -> None:
    rendered = render_template(BASE_VALUES, K3D_VALUES)

    statefulset_docs = gitea_rendered_docs(rendered, kind="StatefulSet")
    workload_docs = statefulset_docs + gitea_rendered_docs(rendered, kind="Deployment")
    if not workload_docs:
        raise SystemExit("k3d overlay did not render a gitea workload")

    service_docs = gitea_rendered_docs(rendered, kind="Service")
    if not service_docs:
        raise SystemExit("k3d overlay did not render a gitea Service")

    ingress_docs = gitea_rendered_docs(rendered, kind="Ingress")
    if not ingress_docs:
        raise SystemExit("k3d overlay did not render a gitea Ingress")

    ingress = ingress_docs[0]
    rendered_class_name = ingress_class_name(ingress)
    if rendered_class_name != "nginx":
        raise SystemExit(
            f"k3d overlay rendered gitea ingressClassName={rendered_class_name!r}, expected 'nginx'"
        )
    hosts = ingress_hosts(ingress)
    if "gitea.localtest.me" not in hosts:
        raise SystemExit(
            f"k3d overlay rendered gitea ingress hosts={hosts!r}, expected 'gitea.localtest.me'"
        )

    for statefulset in statefulset_docs:
        if (
            "volumeClaimTemplates:" in statefulset
            and has_local_path_5gi_persistence(statefulset)
        ):
            return

    pvc_docs = gitea_rendered_docs(rendered, kind="PersistentVolumeClaim")
    for pvc in pvc_docs:
        if has_local_path_5gi_persistence(pvc):
            return

    raise SystemExit(
        "k3d overlay rendered gitea without 5Gi local-path persistence in either StatefulSet volumeClaimTemplates or PersistentVolumeClaim resources"
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

    assert_k3d_gitea_overlay_resources()
    print("k3d overlay: asserted rendered gitea workload/service/ingress + StatefulSet persistence")


if __name__ == "__main__":
    main()
