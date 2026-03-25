#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    bootstrap_config = """\
[providers]
openai_api_key = "test-openai-key"

[hosts]
openclaw = "openclaw.test.internal"
nextcloud = "nextcloud.test.internal"
nextcloud_mcp = "nextcloud-mcp.test.internal"
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

[gitops]
cluster_name = "lab-cluster"
repo_name = "cluster-gitops"
repo_branch = "main"
project = "platform-stack"
robot_username = "gitops-bot"
"""

    with tempfile.TemporaryDirectory() as tmpdir:
        temp_root = Path(tmpdir)
        config_path = temp_root / "bootstrap.local.toml"
        output_dir = temp_root / "repo"
        config_path.write_text(bootstrap_config)

        subprocess.run(
            [
                "python3",
                str(REPO_ROOT / "scripts" / "render-gitops-repo.py"),
                "--output-dir",
                str(output_dir),
                "--bootstrap-config",
                str(config_path),
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
            cwd=REPO_ROOT,
        )

        bootstrap_values = (output_dir / "charts" / "platform-stack" / "clusters" / "lab-cluster" / "bootstrap-values.yaml").read_text()
        gitops_values = (output_dir / "charts" / "platform-stack" / "clusters" / "lab-cluster" / "gitops-values.yaml").read_text()

        assert '"nextcloudMcp"' in bootstrap_values
        assert "nextcloud-mcp.test.internal" in bootstrap_values
        assert '"commands"' in bootstrap_values
        assert '"mcp"' in bootstrap_values
        assert '"servers"' in bootstrap_values
        assert '"nextcloud"' in bootstrap_values
        assert "Authorization=${OPENCLAW_NEXTCLOUD_MCP_AUTH_HEADER}" in bootstrap_values
        assert "${OPENCLAW_NEXTCLOUD_MCP_INTERNAL_URL}" in bootstrap_values
        assert "${OPENCLAW_NEXTCLOUD_MCP_EXTERNAL_URL}" in bootstrap_values
        assert "argoCd:" in gitops_values
        assert "enabled: true" in gitops_values

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
