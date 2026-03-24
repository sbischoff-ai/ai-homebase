#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "scripts" / "render-gitops-repo.py"


def write_config(text: str) -> Path:
    tmpdir = Path(tempfile.mkdtemp())
    path = tmpdir / "bootstrap.local.toml"
    path.write_text(text)
    return path


config = write_config(
    """
[providers]
openai_api_key = "test-openai-key"

[hosts]
openclaw = "openclaw.test.internal"
nextcloud = "nextcloud.test.internal"
gitea = "gitea.test.internal"
argocd = "argocd.test.internal"
vaultwarden = "vaultwarden.test.internal"
paperless = "paperless.test.internal"

[mail]
domain = "example.com"
smtp_host = "smtp.example.com"

[admin]
name = "Test Admin"
username = "test-admin"
email = "admin@example.invalid"
password = "shared-admin-password"
"""
)

output_dir = Path(tempfile.mkdtemp()) / "gitops-repo"
subprocess.run(
    [
        "python3",
        str(SCRIPT),
        "--output-dir",
        str(output_dir),
        "--bootstrap-config",
        str(config),
        "--profile",
        "k3d",
        "--cluster-name",
        "lab-cluster",
        "--release-name",
        "platform-stack",
        "--namespace",
        "ai-homebase",
        "--repo-url",
        "http://platform-stack-gitea-http.ai-homebase.svc.cluster.local:3000/gitops-bot/cluster-gitops.git",
        "--repo-branch",
        "main",
        "--project",
        "platform-stack",
    ],
    check=True,
)

bootstrap_values = (output_dir / "charts" / "platform-stack" / "clusters" / "lab-cluster" / "bootstrap-values.yaml").read_text()
gitops_values = (output_dir / "charts" / "platform-stack" / "clusters" / "lab-cluster" / "gitops-values.yaml").read_text()
project_yaml = (output_dir / "gitops" / "clusters" / "lab-cluster" / "project.yaml").read_text()
app_yaml = (output_dir / "gitops" / "clusters" / "lab-cluster" / "applications" / "platform-stack.yaml").read_text()
root_yaml = (output_dir / "gitops" / "clusters" / "lab-cluster" / "root-application.yaml").read_text()

assert '"argocd": "argocd.test.internal"' in bootstrap_values
assert "argoCd:" in gitops_values
assert "enabled: true" in gitops_values
assert "name: platform-stack" in project_yaml
assert "namespace: ai-homebase" in project_yaml
assert "namespace: kube-system" in project_yaml
assert "repoURL: http://platform-stack-gitea-http.ai-homebase.svc.cluster.local:3000/gitops-bot/cluster-gitops.git" in app_yaml
assert "valueFiles:" in app_yaml
assert "- values-k3d.yaml" in app_yaml
assert "- clusters/lab-cluster/bootstrap-values.yaml" in app_yaml
assert "- clusters/lab-cluster/gitops-values.yaml" in app_yaml
assert "- ServerSideApply=true" in app_yaml
assert "path: gitops/clusters/lab-cluster" in root_yaml

print("render gitops repo tests passed")
