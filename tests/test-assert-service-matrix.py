#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = REPO_ROOT / "scripts" / "ci" / "assert_service_matrix.py"

spec = importlib.util.spec_from_file_location("assert_service_matrix", MODULE_PATH)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)

RENDERED = """# Source: example/templates/gitea-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: platform-stack-gitea
  labels:
    app.kubernetes.io/name: gitea
    app.kubernetes.io/instance: platform-stack
spec: {}
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
---
# Source: example/templates/gitea-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-platform-stack-gitea-0
  labels:
    app.kubernetes.io/name: gitea
    app.kubernetes.io/instance: platform-stack
spec: {}
"""

labels = module.document_metadata_labels(module.split_documents(RENDERED)[0])
assert labels["app.kubernetes.io/name"] == "gitea"
assert labels["app.kubernetes.io/instance"] == "platform-stack"

assert len(module.gitea_labeled_docs(RENDERED, kind="StatefulSet")) == 1
assert len(module.gitea_labeled_docs(RENDERED, kind="Service")) == 1
assert len(module.gitea_labeled_docs(RENDERED, kind="Ingress")) == 1
assert len(module.gitea_labeled_docs(RENDERED, kind="PersistentVolumeClaim")) == 1

print("assert_service_matrix helper tests passed")
