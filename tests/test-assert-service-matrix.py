#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import subprocess

from types import SimpleNamespace
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = REPO_ROOT / "scripts" / "ci" / "assert_service_matrix.py"

spec = importlib.util.spec_from_file_location("assert_service_matrix", MODULE_PATH)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)

RENDERED_WITH_LABELS = """# Source: example/templates/gitea-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: platform-stack-gitea
  labels:
    app.kubernetes.io/name: gitea
    app.kubernetes.io/instance: platform-stack
spec:
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        storageClassName: "local-path"
        resources:
          requests:
            storage: "5Gi"
---
# Source: example/templates/gitea-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: platform-stack-gitea-http
  labels:
    app.kubernetes.io/name: gitea
    app.kubernetes.io/instance: platform-stack
spec: {}
---
# Source: example/templates/gitea-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: platform-stack-gitea
  labels:
    app.kubernetes.io/name: gitea
    app.kubernetes.io/instance: platform-stack
spec:
  ingressClassName: nginx
  rules:
    - host: gitea.localtest.me
"""

RENDERED_WITH_NAME_FALLBACK = """# Source: example/templates/gitea-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: platform-stack-gitea
spec:
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        storageClassName: "local-path"
        resources:
          requests:
            storage: "5Gi"
---
# Source: example/templates/gitea-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: platform-stack-gitea-http
spec: {}
---
# Source: example/templates/gitea-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: platform-stack-gitea
spec:
  ingressClassName: nginx
  rules:
    - host: gitea.localtest.me
"""

RENDERED_WITH_DEPLOYMENT_AND_PVC = """# Source: platform-stack/charts/gitea/charts/gitea/templates/gitea/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-gitea-workload
spec: {}
---
# Source: platform-stack/charts/gitea/charts/gitea/templates/gitea/service-http.yaml
apiVersion: v1
kind: Service
metadata:
  name: custom-gitea-http
spec: {}
---
# Source: platform-stack/charts/gitea/charts/gitea/templates/gitea/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: custom-gitea-ingress
spec:
  ingressClassName: nginx
  rules:
    - host: gitea.localtest.me
---
# Source: platform-stack/charts/gitea/charts/gitea/templates/gitea/pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: custom-gitea-pvc
spec:
  storageClass: "local-path"
  resources:
    requests:
      storage: "5Gi"
"""

labels = module.document_metadata_labels(module.split_documents(RENDERED_WITH_LABELS)[0])
assert labels["app.kubernetes.io/name"] == "gitea"
assert labels["app.kubernetes.io/instance"] == "platform-stack"

for values_path in (
    REPO_ROOT / "charts" / "gitea" / "values.yaml",
    REPO_ROOT / "charts" / "platform-stack" / "values.yaml",
):
    values_text = values_path.read_text()
    assert "actions:" not in values_text
    assert "repository: gitea" in values_text
    assert 'tag: "1.25.5"' in values_text
    assert 'valkey:' in values_text
    assert 'valkey-cluster:' in values_text
    assert 'redis-cluster:' not in values_text

for values_path in (
    REPO_ROOT / "charts" / "gitea" / "values.yaml",
    REPO_ROOT / "charts" / "platform-stack" / "values.yaml",
):
    values_text = values_path.read_text()
    assert "- name: GITEA__database__PASSWD" in values_text
    assert "name: gitea-config-secrets" in values_text
    assert "key: GITEA__database__PASSWD" in values_text
    assert "- GITEA__database__PASSWD" not in values_text

bootstrap_secret_script = (REPO_ROOT / "scripts" / "k3d-bootstrap-secrets.sh").read_text()
assert "create_and_apply_secret gitea-config-secrets" in bootstrap_secret_script
assert "CREATE ROLE gitea LOGIN PASSWORD" in bootstrap_secret_script
assert "CREATE DATABASE gitea OWNER gitea" in bootstrap_secret_script

assert len(module.gitea_rendered_docs(RENDERED_WITH_LABELS, kind="StatefulSet")) == 1
assert len(module.gitea_rendered_docs(RENDERED_WITH_LABELS, kind="Service")) == 1
assert len(module.gitea_rendered_docs(RENDERED_WITH_LABELS, kind="Ingress")) == 1
assert "volumeClaimTemplates:" in module.gitea_rendered_docs(RENDERED_WITH_LABELS, kind="StatefulSet")[0]
assert module.has_local_path_5gi_persistence(module.gitea_rendered_docs(RENDERED_WITH_LABELS, kind="StatefulSet")[0])

assert len(module.gitea_rendered_docs(RENDERED_WITH_NAME_FALLBACK, kind="StatefulSet")) == 1
assert len(module.gitea_rendered_docs(RENDERED_WITH_NAME_FALLBACK, kind="Service")) == 1
assert len(module.gitea_rendered_docs(RENDERED_WITH_NAME_FALLBACK, kind="Ingress")) == 1
assert "volumeClaimTemplates:" in module.gitea_rendered_docs(RENDERED_WITH_NAME_FALLBACK, kind="StatefulSet")[0]
assert module.has_local_path_5gi_persistence(module.gitea_rendered_docs(RENDERED_WITH_NAME_FALLBACK, kind="StatefulSet")[0])

assert len(module.gitea_rendered_docs(RENDERED_WITH_DEPLOYMENT_AND_PVC, kind="Deployment")) == 1
assert len(module.gitea_rendered_docs(RENDERED_WITH_DEPLOYMENT_AND_PVC, kind="Service")) == 1
assert len(module.gitea_rendered_docs(RENDERED_WITH_DEPLOYMENT_AND_PVC, kind="Ingress")) == 1
assert len(module.gitea_rendered_docs(RENDERED_WITH_DEPLOYMENT_AND_PVC, kind="PersistentVolumeClaim")) == 1
assert module.has_local_path_5gi_persistence(module.gitea_rendered_docs(RENDERED_WITH_DEPLOYMENT_AND_PVC, kind="PersistentVolumeClaim")[0])

calls: list[list[str]] = []


def fake_run(cmd: list[str], check: bool, capture_output: bool, text: bool) -> SimpleNamespace:
    calls.append(cmd)
    if cmd[:3] == ["helm", "template", "platform-stack"]:
        return SimpleNamespace(stdout="kind: ConfigMap\nmetadata:\n  name: test\n")
    return SimpleNamespace(stdout="")


module._DEPENDENCIES_READY = False
real_run = module.subprocess.run
module.subprocess.run = fake_run
try:
    module.render_template(module.BASE_VALUES, module.K3D_VALUES)
finally:
    module.subprocess.run = real_run

assert calls[:3] == [
    ["helm", "dependency", "update", "charts/gitea"],
    ["helm", "dependency", "update", "charts/platform-stack"],
    ["helm", "template", "platform-stack", "charts/platform-stack", "-f", module.BASE_VALUES, "-f", module.K3D_VALUES],
]


def fake_run_failure(cmd: list[str], check: bool, capture_output: bool, text: bool) -> SimpleNamespace:
    raise subprocess.CalledProcessError(1, cmd, stderr="template error details")


module._DEPENDENCIES_READY = True
module.subprocess.run = fake_run_failure
try:
    try:
        module.render_template(module.BASE_VALUES)
        raise AssertionError("expected render_template() to raise SystemExit")
    except SystemExit as exc:
        message = str(exc)
        assert "failed to render Helm templates" in message
        assert "template error details" in message
finally:
    module.subprocess.run = real_run

real_render_template = module.render_template
module.render_template = lambda *args, **kwargs: RENDERED_WITH_DEPLOYMENT_AND_PVC
try:
    module.assert_k3d_gitea_overlay_resources()
finally:
    module.render_template = real_render_template

print("assert_service_matrix helper tests passed")
