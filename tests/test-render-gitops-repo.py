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
anthropic_api_key = "test-anthropic-key"

[openclaw.agents.main]
model = "anthropic/claude-sonnet-4-6"

[openclaw.agents.coder]
model = "anthropic/claude-sonnet-4-5"

[openclaw.agents.coder.gitea]
username = "coder-bot"

[openclaw.agents.architect]
model = "anthropic/claude-opus-4-6"

[openclaw.agents.archivist]
model = "anthropic/claude-sonnet-4-6"

[openclaw.agents.watchdog]
model = "anthropic/claude-haiku-4-5"

[hosts]
openclaw = "openclaw.test.internal"
nextcloud = "nextcloud.test.internal"
nextcloud_mcp = "nextcloud-mcp.test.internal"
qdrant = "qdrant.test.internal"
qdrant_mcp = "qdrant-mcp.test.internal"
memgraph = "memgraph.test.internal"
memgraph_lab = "memgraph-lab.test.internal"
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
                "http://platform-stack-gitea-http.ai-homebase.svc.cluster.local:3000/coder-bot/cluster-gitops.git",
                "--repo-branch",
                "main",
                "--project",
                "platform-stack",
                "--remote-docker-host",
                "10.10.0.1",
                "--remote-docker-port",
                "2222",
            ],
            check=True,
            cwd=REPO_ROOT,
        )

        bootstrap_values = (output_dir / "charts" / "platform-stack" / "clusters" / "lab-cluster" / "bootstrap-values.yaml").read_text()
        gitops_values = (output_dir / "charts" / "platform-stack" / "clusters" / "lab-cluster" / "gitops-values.yaml").read_text()
        assert '"nextcloudMcp"' in bootstrap_values
        assert "nextcloud-mcp.test.internal" in bootstrap_values
        assert '"commands"' in bootstrap_values
        assert '"tools"' in bootstrap_values
        assert '"agentToAgent"' in bootstrap_values
        assert '"models"' in bootstrap_values
        assert '"coder"' in bootstrap_values
        assert '"architect"' in bootstrap_values
        assert '"watchdog"' in bootstrap_values
        assert '"archivist"' in bootstrap_values
        assert 'claude-opus-4-6' in bootstrap_values
        assert 'claude-haiku-4-5' in bootstrap_values
        assert 'memgraph.test.internal' in bootstrap_values
        assert 'memgraph-lab.test.internal' in bootstrap_values
        assert '"mcp"' in bootstrap_values
        assert '"servers"' in bootstrap_values
        assert '"nextcloud"' in bootstrap_values
        assert '"bootstrapProjectContent"' in bootstrap_values
        assert '/Projects/ai-homebase/' in bootstrap_values
        assert 'multi-agent-topology.md' in bootstrap_values
        assert 'qdrant-memory-schema.md' in bootstrap_values
        assert 'knowledge-graph-schema.md' in bootstrap_values
        assert 'incidents/README.md' in bootstrap_values
        assert 'baselines.md' in bootstrap_values
        assert 'escalation-rules.md' in bootstrap_values
        assert '"workspaceBootstrap"' in bootstrap_values
        assert '"BOOTSTRAP.md"' in bootstrap_values
        assert '# Memory - Main Agent' in bootstrap_values
        assert '[domain] [kind] Complete statement here.' in bootstrap_values
        assert '## Task Classification Gate (mandatory)' in bootstrap_values
        assert '## Task Handoff' in bootstrap_values
        assert '## Watchdog Alert' in bootstrap_values
        assert '"allowBundled"' in bootstrap_values
        assert "Authorization=${OPENCLAW_NEXTCLOUD_MCP_AUTH_HEADER}" in bootstrap_values
        assert "${OPENCLAW_NEXTCLOUD_MCP_INTERNAL_URL}" in bootstrap_values
        assert "${OPENCLAW_NEXTCLOUD_MCP_EXTERNAL_URL}" in bootstrap_values
        assert "/opt/openclaw-runtime/mcp/mcp-http-bridge.mjs" in bootstrap_values
        assert "openclaw-sandbox-archivist:bookworm-slim" in bootstrap_values
        assert "openclaw-sandbox-coder:bookworm-slim" in bootstrap_values
        assert 'export HOME=/workspace/.home' in bootstrap_values
        assert 'CODEX_HOME' in bootstrap_values
        assert '/.codex' in bootstrap_values
        assert '/workspace` is your repo working tree; persistent tool state lives under `/workspace/.home`' in bootstrap_values
        assert '"skills/gitea-tea/SKILL.md"' not in bootstrap_values
        assert '"skills/gitops-homebase/SKILL.md"' not in bootstrap_values
        assert 'Use `tea` for repository creation' in bootstrap_values
        assert 'Treat the GitOps repository as a deployment-definition repo' in bootstrap_values
        assert "toolDescriptions:" in (REPO_ROOT / "charts" / "platform-stack" / "values.yaml").read_text()
        assert "Store a memory for cross-agent recall." in (REPO_ROOT / "charts" / "platform-stack" / "values.yaml").read_text()
        assert "argoCd:" in gitops_values
        assert "enabled: true" in gitops_values
        assert "dockerHost: ssh://docker-remote@10.10.0.1:2222" in gitops_values

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
