#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "scripts" / "bootstrap-config.py"

def write_config(text: str) -> Path:
    tmpdir = Path(tempfile.mkdtemp())
    path = tmpdir / "bootstrap.local.toml"
    path.write_text(text)
    return path


valid_config = write_config(
    """
[providers]
openai_api_key = "test-openai-key"
anthropic_api_key = "test-anthropic-key"
brave_api_key = "test-brave-key"

[openclaw.agents.main]
model = "openai/gpt-4.1"
fallback_models = ["anthropic/claude-sonnet-4-6"]

[openclaw.agents.coder]
model = "anthropic/claude-sonnet-4-6"
fallback_models = ["openai/gpt-4.1"]

[openclaw.agents.coder.gitea]
username = "coder-bot"
password = "coder-password"

[openclaw.agents.architect]
model = "anthropic/claude-opus-4-6"
fallback_models = ["openai/o3"]

[openclaw.agents.archivist]
model = "anthropic/claude-sonnet-4-6"
fallback_models = ["openai/gpt-4.1-mini"]

[openclaw.agents.watchdog]
model = "openai/gpt-4.1-nano"
fallback_models = ["anthropic/claude-haiku-4-5"]

[hosts]
openclaw = "openclaw.test.internal"
nextcloud = "nextcloud.test.internal"
nextcloud_mcp = "nextcloud-mcp.test.internal"
qdrant = "qdrant.test.internal"
qdrant_mcp = "qdrant-mcp.test.internal"
memgraph = "memgraph.test.internal"
memgraph_lab = "memgraph-lab.test.internal"
nextcloud_public = "nextcloud.example.com"
gitea = "gitea.test.internal"
registry = "registry.test.internal"
argocd = "argocd.test.internal"
vaultwarden = "vaultwarden.test.internal"
paperless = "paperless.test.internal"

[mail]
domain = "example.com"
smtp_host = "smtp.example.com"
from_localpart = "noreply"
from_name = "Test Homebase"

[admin]
name = "Test Admin"
username = "test-admin"
email = "admin@example.invalid"
password = "shared-admin-password"

[services.gitea.admin]
email = "git@example.invalid"

[services.registry.auth]
username = "coder"
password = "registry-password"

[services.argocd.admin]
user = "admin"
password = "argocd-admin-password"

[secrets]
vaultwarden_admin_token = "vaultwarden-admin-token"
openclaw_nextcloud_mcp_password = "nextcloud-mcp-password"
github_token = "github-token"

[gitops]
cluster_name = "lab-cluster"
repo_name = "cluster-gitops"
repo_branch = "main"
repo_private = true
project = "platform-stack"
"""
)

result = subprocess.run(
    ["python3", str(SCRIPT), "validate", "--config", str(valid_config)],
    check=True,
    capture_output=True,
    text=True,
)
assert "bootstrap config is valid" in result.stdout

shell_vars = subprocess.run(
    ["python3", str(SCRIPT), "shell-vars", "--config", str(valid_config)],
    check=True,
    capture_output=True,
    text=True,
).stdout
assert "OPENAI_API_KEY=test-openai-key" in shell_vars
assert "ANTHROPIC_API_KEY=test-anthropic-key" in shell_vars
assert "BRAVE_API_KEY=test-brave-key" in shell_vars
assert "OPENCLAW_MAIN_MODEL=openai/gpt-4.1" in shell_vars
assert "OPENCLAW_CODER_MODEL=anthropic/claude-sonnet-4-6" in shell_vars
assert "GITHUB_TOKEN=github-token" in shell_vars
assert "OPENCLAW_ARCHITECT_MODEL=anthropic/claude-opus-4-6" in shell_vars
assert "OPENCLAW_ARCHIVIST_MODEL=anthropic/claude-sonnet-4-6" in shell_vars
assert "OPENCLAW_WATCHDOG_MODEL=openai/gpt-4.1-nano" in shell_vars
assert "GITEA_ADMIN_EMAIL=git@example.invalid" in shell_vars
assert "NEXTCLOUD_ADMIN_USER=test-admin" in shell_vars
assert "NEXTCLOUD_MCP_HOST=nextcloud-mcp.test.internal" in shell_vars
assert "PAPERLESS_ADMIN_MAIL=admin@example.invalid" in shell_vars
assert "OPENCLAW_HOST=openclaw.test.internal" in shell_vars
assert "NEXTCLOUD_PUBLIC_HOST=nextcloud.example.com" in shell_vars
assert "REGISTRY_HOST=registry.test.internal" in shell_vars
assert "MEMGRAPH_HOST=memgraph.test.internal" in shell_vars
assert "MEMGRAPH_LAB_HOST=memgraph-lab.test.internal" in shell_vars
assert "ARGOCD_HOST=argocd.test.internal" in shell_vars
assert "PAPERLESS_HOST=paperless.test.internal" in shell_vars
assert "MAIL_DOMAIN=example.com" in shell_vars
assert "MAIL_SMTP_HOST=smtp.example.com" in shell_vars
assert "MAIL_FROM_LOCALPART=noreply" in shell_vars
assert "VAULTWARDEN_ADMIN_TOKEN=vaultwarden-admin-token" in shell_vars
assert "OPENCLAW_NEXTCLOUD_MCP_PASSWORD=nextcloud-mcp-password" in shell_vars
assert "ARGOCD_ADMIN_USER=admin" in shell_vars
assert "ARGOCD_ADMIN_PASSWORD=argocd-admin-password" in shell_vars
assert "GITOPS_CLUSTER_NAME=lab-cluster" in shell_vars
assert "CODER_GITEA_USERNAME=coder-bot" in shell_vars
assert "CODER_GITEA_EMAIL=coder-bot@example.invalid" in shell_vars
assert "CODER_GITEA_PASSWORD=coder-password" in shell_vars
assert "REGISTRY_USERNAME=coder" in shell_vars
assert "REGISTRY_PASSWORD=registry-password" in shell_vars
assert "GITOPS_REPO_PRIVATE=true" in shell_vars

rendered_values = json.loads(
    subprocess.run(
        ["python3", str(SCRIPT), "render-values", "--config", str(valid_config)],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
)
assert rendered_values["openclaw"]["secretKeys"]["openaiApiKey"] == "OPENAI_API_KEY"
assert rendered_values["openclaw"]["secretKeys"]["anthropicApiKey"] == "ANTHROPIC_API_KEY"
assert rendered_values["openclaw"]["secretKeys"]["githubToken"] == "GITHUB_TOKEN"
assert rendered_values["openclaw"]["openclaw"]["agents"]["defaults"]["workspace"] == "/home/node/.openclaw/workspace"
assert rendered_values["openclaw"]["openclaw"]["skills"]["allowBundled"] == [
    "weather",
    "healthcheck",
    "node-connect",
    "skill-creator",
    "session-logs",
    "coding-agent",
    "tmux",
    "summarize",
    "github",
]
assert rendered_values["openclaw"]["openclaw"]["agents"]["defaults"]["models"] == {
    "openai/gpt-4.1": {"alias": "Main / Coder"},
    "anthropic/claude-sonnet-4-6": {"alias": "Main / Coder / Archivist"},
    "anthropic/claude-opus-4-6": {"alias": "Architect / Auditor"},
    "openai/o3": {"alias": "Architect"},
    "openai/gpt-4.1-mini": {"alias": "Archivist"},
    "openai/gpt-4.1-nano": {"alias": "Watchdog"},
    "anthropic/claude-haiku-4-5": {"alias": "Watchdog"},
    "openai/gpt-5.4": {"alias": "Auditor"},
}
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][0]["id"] == "main"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][0]["default"] is True
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][0]["model"]["primary"] == "openai/gpt-4.1"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][0]["model"]["fallbacks"] == ["anthropic/claude-sonnet-4-6"]
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["id"] == "coder"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["workspace"] == "/home/node/.openclaw/workspace-coder"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["model"]["primary"] == "anthropic/claude-sonnet-4-6"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["model"]["fallbacks"] == ["openai/gpt-4.1"]
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["mode"] == "all"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["workspaceAccess"] == "rw"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["image"] == "registry.test.internal/coder-bot/openclaw-sandbox-coder:trixie-slim"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["HOME"] == "/workspace/.home"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["CODEX_HOME"] == "/workspace/.home/.codex"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["XDG_CONFIG_HOME"] == "/workspace/.home/.config"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["XDG_CACHE_HOME"] == "/workspace/.home/.cache"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["XDG_STATE_HOME"] == "/workspace/.home/.local/state"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["CODER_GITEA_USERNAME"] == "coder-bot"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["CODER_GITEA_HOST"] == "gitea.test.internal"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["CODER_GITEA_BASE_URL"] == "https://gitea.test.internal"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["CODER_GITEA_TEA_LOGIN_NAME"] == "coder"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["CODER_GITEA_TEA_TOKEN_NAME"] == "openclaw-coder-sandbox"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["CODER_REGISTRY_HOST"] == "registry.test.internal"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["CODER_REGISTRY_BASE_URL"] == "https://registry.test.internal"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["CODER_REGISTRY_USERNAME"] == "coder"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["CODER_REGISTRY_NAMESPACE"] == "coder-bot"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["OPENAI_API_KEY"] == "${OPENAI_API_KEY}"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["GITHUB_TOKEN"] == "${GITHUB_TOKEN}"
assert 'export HOME=/workspace/.home' in rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["setupCommand"]
assert 'export CODEX_HOME="$HOME/.codex"' in rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["setupCommand"]
assert 'mkdir -p "$CODEX_HOME" "$XDG_CONFIG_HOME/tea" "$XDG_CACHE_HOME" "$XDG_STATE_HOME" "$HOME/.docker"' in rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["setupCommand"]
assert "git config --global user.name" in rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["setupCommand"]
assert "machine gitea.test.internal" in rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["setupCommand"]
assert "tea login add --name coder" in rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["setupCommand"]
assert 'docker login ' in rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["setupCommand"]
assert "${CODER_GITEA_USERNAME}" not in rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["setupCommand"]
assert "/workspace" not in rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"].get("tmpfs", [])
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][2]["id"] == "architect"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][2]["workspace"] == "/home/node/.openclaw/workspace-architect"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][2]["model"]["primary"] == "anthropic/claude-opus-4-6"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][2]["model"]["fallbacks"] == ["openai/o3"]
assert "tools" not in rendered_values["openclaw"]["openclaw"]["agents"]["list"][2]
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][3]["id"] == "archivist"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][3]["workspace"] == "/home/node/.openclaw/workspace-archivist"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][3]["model"]["primary"] == "anthropic/claude-sonnet-4-6"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][3]["model"]["fallbacks"] == ["openai/gpt-4.1-mini"]
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][3]["sandbox"] == {"mode": "non-main"}
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][4]["id"] == "watchdog"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][4]["workspace"] == "/home/node/.openclaw/workspace-watchdog"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][4]["model"]["primary"] == "openai/gpt-4.1-nano"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][4]["model"]["fallbacks"] == ["anthropic/claude-haiku-4-5"]
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][4]["sandbox"]["mode"] == "off"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][0]["subagents"]["allowAgents"] == ["coder", "architect", "archivist", "auditor"]
assert rendered_values["openclaw"]["openclaw"]["tools"]["agentToAgent"]["enabled"] is True
assert rendered_values["openclaw"]["openclaw"]["tools"]["agentToAgent"]["allow"] == ["main", "coder", "architect", "archivist", "watchdog", "auditor"]
assert rendered_values["openclaw"]["openclaw"]["tools"]["sessions"]["visibility"] == "all"
assert rendered_values["openclaw"]["openclaw"]["plugins"]["slots"]["memory"] == "none"
assert rendered_values["openclaw"]["workspaceBootstrap"]["enabled"] is True
assert rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["workspace"] == "/home/node/.openclaw/workspace"
assert "openclaw" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["TOOLS.md"]
assert "test-admin" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["USER.md"]
assert "### Nextcloud Usage - Main" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["TOOLS.md"]
assert "Before routing work to a specialist" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["TOOLS.md"]
assert "store a Qdrant memory summarizing it" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["TOOLS.md"]
assert "## Task Classification Gate (mandatory)" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["AGENTS.md"]
assert "## Handoff Protocol" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["AGENTS.md"]
assert "## Task Handoff" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["AGENTS.md"]
assert "Main is the only agent that spawns sub-agents." in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["AGENTS.md"]
assert "Would you like a morning brief and evening digest?" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "Ask the user how they want to be addressed." in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "Ask how they want to address you." in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "Ask for their preferred conversation style or personality." in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "Ask what they want to do with this setup." in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "The bootstrapped Nextcloud username for the user is currently `test-admin`." in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "share these existing top-level folders with that username" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "- `/Projects/`" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "- `/Notes/`" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "Use `sessions_send` to target these literal session keys" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "`agent:coder:main`" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "`agent:architect:main`" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "`agent:archivist:main`" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "`agent:watchdog:main`" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "`agent:auditor:main`" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "Ask each agent for a short readiness confirmation and verify they respond." in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "Morning brief" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "Evening digest" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "I'll create the cron jobs using `openclaw cron add`." in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "share it with the `openclaw` user" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "/Projects/ai-homebase/" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "/Notes/ai-homebase/" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "I should share both `/Projects/` and `/Notes/` with your user." in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "# Memory - Main Agent" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["MEMORY.md"]
assert '[domain] [kind] Complete statement here.' in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["MEMORY.md"]
assert '"agent": "main"' in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["MEMORY.md"]
assert "planning and design specialist" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["architect"]["files"]["AGENTS.md"]
assert "## Task Classification Gate (mandatory)" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["architect"]["files"]["AGENTS.md"]
assert "## Handoff Complete" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["architect"]["files"]["AGENTS.md"]
assert "implementation and execution specialist" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["AGENTS.md"]
assert "If the spec or plan has gaps that require design decisions, stop" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["AGENTS.md"]
assert "monitoring and triage specialist" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["watchdog"]["files"]["AGENTS.md"]
assert "knowledge graph curator" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["archivist"]["files"]["AGENTS.md"]
assert "mgconsole" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["archivist"]["files"]["TOOLS.md"]
assert "/Projects/ai-homebase/knowledge-graph-schema.md" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["archivist"]["files"]["TOOLS.md"]
assert "## Watchdog Alert" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["watchdog"]["files"]["AGENTS.md"]
assert "/Projects/ai-homebase/incidents/" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["watchdog"]["files"]["TOOLS.md"]
assert "/Projects/ai-homebase/baselines.md" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["watchdog"]["files"]["TOOLS.md"]
assert "coder-bot" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "test-admin" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["USER.md"]
assert "append the decision and rationale to `/Projects/<slug>/decisions.md`" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "Code, configs, and scripts stay in repositories" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "agent:main:main" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "Use `tea` for repository creation" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "If `GITHUB_TOKEN` is present" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "Your primary coding execution path is the `coding-agent` flow backed by Codex CLI." in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "Treat the GitOps repository as a deployment-definition repo" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "Default new cluster-bound images to the in-cluster registry" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "Common tools available include `bash`" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "/workspace` is your repo working tree; persistent tool state lives under `/workspace/.home`" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "`HOME`, `CODEX_HOME`, and XDG directories are preconfigured inside `/workspace/.home`" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "The Gitea ingress hostname `gitea.test.internal` should resolve from your sandbox runtime." in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "The registry hostname `registry.test.internal` should resolve from your sandbox runtime" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "skills/gitea-tea/SKILL.md" not in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]
assert "skills/gitops-homebase/SKILL.md" not in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]
assert "/Projects/<slug>/decisions.md" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["architect"]["files"]["TOOLS.md"]
assert "-archived-YYYY-MM-DD" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["architect"]["files"]["TOOLS.md"]
assert "Qdrant memory summarizing the key decisions" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["architect"]["files"]["TOOLS.md"]
assert "Existing seeded project:" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["architect"]["files"]["MEMORY.md"]
assert "/Projects/ai-homebase/" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["architect"]["files"]["MEMORY.md"]
assert "/Notes/ai-homebase/" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["architect"]["files"]["MEMORY.md"]
assert '[domain] [kind] Complete statement here.' in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["architect"]["files"]["MEMORY.md"]
assert '"agent": "architect"' in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["architect"]["files"]["MEMORY.md"]
assert '# Memory - Coder Agent' in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["MEMORY.md"]
assert "Traverse Memgraph first" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["archivist"]["files"]["AGENTS.md"]
assert "Use `mgconsole` as the canonical Memgraph client" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["archivist"]["files"]["TOOLS.md"]
assert "queries/entity-by-slug.cypher" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["archivist"]["files"]
assert "MEMGRAPH_HOST" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["archivist"]["files"]["queries/README.md"]
assert "knowledge-graph-schema.md" in json.dumps(rendered_values["nextcloud"]["bootstrapProjectContent"])
assert rendered_values["memgraph"]["ingress"]["hosts"][0]["host"] == "memgraph.test.internal"
assert rendered_values["memgraphLab"]["ingress"]["hosts"][0]["host"] == "memgraph-lab.test.internal"
assert '"agent": "coder"' in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["MEMORY.md"]
assert '# Memory - Watchdog Agent' in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["watchdog"]["files"]["MEMORY.md"]
assert '"agent": "watchdog"' in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["watchdog"]["files"]["MEMORY.md"]
assert rendered_values["openclaw"]["ingress"]["hosts"][0]["host"] == "openclaw.test.internal"
assert rendered_values["gitea"]["gitea"]["gitea"]["admin"]["existingSecret"] == "gitea-admin-secret"
assert rendered_values["gitea"]["gitea"]["ingress"]["hosts"][0]["host"] == "gitea.test.internal"
assert rendered_values["registry"]["auth"]["existingSecret"] == "registry-auth-secret"
assert rendered_values["registry"]["ingress"]["hosts"][0]["host"] == "registry.test.internal"
assert rendered_values["registry"]["ingress"]["tls"][0]["secretName"] == "registry-tls"
assert rendered_values["argoCd"]["argocd"]["server"]["ingress"]["hostname"] == "argocd.test.internal"
assert rendered_values["nextcloud"]["admin"]["user"] == "test-admin"
assert rendered_values["nextcloud"]["bootstrapUsers"][0]["username"] == "openclaw"
assert rendered_values["nextcloud"]["bootstrapUsers"][0]["displayName"] == "OpenClaw"
assert rendered_values["nextcloud"]["bootstrapProjectContent"][0]["slug"] == "ai-homebase"
assert rendered_values["nextcloud"]["bootstrapProjectContent"][0]["ownerUsername"] == "openclaw"
assert rendered_values["nextcloud"]["bootstrapProjectContent"][0]["projectsFiles"][0]["path"] == "overview.md"
assert "running AI homebase cluster" in rendered_values["nextcloud"]["bootstrapProjectContent"][0]["projectsFiles"][0]["content"]
project_files = rendered_values["nextcloud"]["bootstrapProjectContent"][0]["projectsFiles"]
assert any(item["path"] == "qdrant-memory-schema.md" and "Qdrant Semantic Memory Schema" in item["content"] for item in project_files)
assert any(item["path"] == "knowledge-graph-schema.md" and "Knowledge Graph Schema" in item["content"] for item in project_files)
assert any(item["path"] == "incidents/README.md" for item in project_files)
assert any(item["path"] == "baselines.md" for item in project_files)
assert any(item["path"] == "escalation-rules.md" for item in project_files)
assert rendered_values["nextcloud"]["bootstrapProjectContent"][0]["notes"][0]["path"] == "project-brief.md"
assert "standing project for documenting and improving the cluster itself" in rendered_values["nextcloud"]["bootstrapProjectContent"][0]["notes"][0]["content"]
assert rendered_values["nextcloud"]["ingress"]["private"]["host"] == "nextcloud.test.internal"
assert rendered_values["nextcloud"]["ingress"]["public"]["host"] == "nextcloud.example.com"
assert rendered_values["nextcloud"]["smtp"]["host"] == "platform-stack-postfix-relay"
assert rendered_values["nextcloud"]["smtp"]["domain"] == "example.com"
assert rendered_values["nextcloud"]["trustedDomains"] == [
    "nextcloud.test.internal",
    "nextcloud.example.com",
    "platform-stack-nextcloud",
    "platform-stack-nextcloud.ai-homebase.svc",
    "platform-stack-nextcloud.ai-homebase.svc.cluster.local",
]
assert rendered_values["vaultwarden"]["existingSecret"] == "vaultwarden-config-secrets"
assert rendered_values["vaultwarden"]["ingress"]["hosts"][0]["host"] == "vaultwarden.test.internal"
assert rendered_values["vaultwarden"]["ingress"]["tls"][0]["secretName"] == "vaultwarden-tls"
assert rendered_values["vaultwarden"]["smtp"]["from"] == "noreply@example.com"
assert rendered_values["nextcloudMcp"]["ingress"]["hosts"][0]["host"] == "nextcloud-mcp.test.internal"
assert rendered_values["openclaw"]["openclaw"]["commands"]["mcp"] is True
assert rendered_values["openclaw"]["openclaw"]["mcp"]["servers"]["nextcloud"]["args"][0] == "/opt/openclaw-runtime/mcp/mcp-http-bridge.mjs"
assert rendered_values["openclaw"]["openclaw"]["mcp"]["servers"]["nextcloud"]["args"][2] == "${OPENCLAW_NEXTCLOUD_MCP_INTERNAL_URL}"
assert rendered_values["openclaw"]["openclaw"]["mcp"]["servers"]["nextcloud"]["args"][4] == "${OPENCLAW_NEXTCLOUD_MCP_EXTERNAL_URL}"
assert rendered_values["paperlessNgx"]["admin"]["mail"] == "admin@example.invalid"
assert rendered_values["paperlessNgx"]["ingress"]["hosts"][0]["host"] == "paperless.test.internal"
assert rendered_values["global"]["mail"]["smtpHost"] == "smtp.example.com"
assert rendered_values["global"]["hosts"]["registry"] == "registry.test.internal"
assert rendered_values["openclaw"]["env"] == [
    {"name": "MEMGRAPH_HOST", "value": "memgraph.test.internal"},
    {"name": "MEMGRAPH_PORT", "value": "7687"},
    {"name": "MEMGRAPH_BOLT_URI", "value": "bolt://memgraph.test.internal:7687"},
]
assert rendered_values["openclaw"]["openclaw"]["agents"]["defaults"]["sandbox"]["docker"]["env"] == {
    "MEMGRAPH_HOST": "memgraph.test.internal",
    "MEMGRAPH_PORT": "7687",
    "MEMGRAPH_BOLT_URI": "bolt://memgraph.test.internal:7687",
}

coder_dockerfile = (REPO_ROOT / "images" / "openclaw-sandbox-coder" / "Dockerfile").read_text(encoding="utf-8")
base_dockerfile = (REPO_ROOT / "images" / "openclaw-sandbox-base" / "Dockerfile").read_text(encoding="utf-8")
gateway_dockerfile = (REPO_ROOT / "images" / "openclaw-remote-docker" / "Dockerfile").read_text(encoding="utf-8")
qdrant_mcp_values = (REPO_ROOT / "charts" / "qdrant-mcp" / "values.yaml").read_text(encoding="utf-8")
assert "usermod --home /home/sandbox sandbox" in coder_dockerfile
assert "mkdir -p /home/sandbox /workspace" in coder_dockerfile
assert "ENV HOME=/workspace" not in coder_dockerfile
assert "WORKDIR /workspace" in coder_dockerfile
assert "tmux" in coder_dockerfile
assert "@openai/codex" in coder_dockerfile
assert "debian:trixie-slim" in base_dockerfile
assert "COPY --from=memgraph-tools /usr/bin/mgconsole /usr/local/bin/mgconsole" in base_dockerfile
assert "debian:trixie-slim" in gateway_dockerfile
assert "COPY --from=openclaw-runtime /app /app" in gateway_dockerfile
assert "COPY --from=memgraph-tools /usr/bin/mgconsole /usr/local/bin/mgconsole" in gateway_dockerfile
assert "toolDescriptions:" in qdrant_mcp_values
assert "Store a memory for cross-agent recall." in qdrant_mcp_values
assert "Search shared semantic memory across all agents." in qdrant_mcp_values

invalid_config = write_config(
    """
[providers]
openai_api_key = ""
anthropic_api_key = ""

[mail]
domain = "example.com"
smtp_host = "smtp.example.com"
"""
)

failed = subprocess.run(
    ["python3", str(SCRIPT), "validate", "--config", str(invalid_config)],
    check=False,
    capture_output=True,
    text=True,
)
assert failed.returncode != 0
assert "At least one supported OpenClaw provider/search key is required" in failed.stderr

missing_openai_for_coder_config = write_config(
    """
[providers]
openai_api_key = ""
anthropic_api_key = "test-anthropic-key"

[openclaw.agents.main]
model = "anthropic/claude-sonnet-4-6"

[openclaw.agents.coder]
model = "anthropic/claude-sonnet-4-5"

[openclaw.agents.architect]
model = "anthropic/claude-opus-4-6"

[mail]
domain = "example.com"
smtp_host = "smtp.example.com"
"""
)

failed = subprocess.run(
    ["python3", str(SCRIPT), "validate", "--config", str(missing_openai_for_coder_config)],
    check=False,
    capture_output=True,
    text=True,
)
assert failed.returncode != 0
assert "OPENAI_API_KEY is required in [providers] for the bootstrapped coder Codex workflow." in failed.stderr

invalid_argocd_user_config = write_config(
    """
[providers]
openai_api_key = "test-openai-key"
anthropic_api_key = "test-anthropic-key"

[openclaw.agents.main]
model = "anthropic/claude-sonnet-4-6"

[openclaw.agents.coder]
model = "anthropic/claude-sonnet-4-5"

[openclaw.agents.architect]
model = "anthropic/claude-opus-4-6"

[mail]
domain = "example.com"
smtp_host = "smtp.example.com"

[services.argocd.admin]
user = "operator with spaces"
password = "secret"
"""
)

failed = subprocess.run(
    ["python3", str(SCRIPT), "validate", "--config", str(invalid_argocd_user_config)],
    check=False,
    capture_output=True,
    text=True,
)
assert failed.returncode != 0
assert "services.argocd.admin.user must match" in failed.stderr

custom_argocd_user_config = write_config(
    """
[providers]
openai_api_key = "test-openai-key"
anthropic_api_key = "test-anthropic-key"

[openclaw.agents.main]
model = "anthropic/claude-sonnet-4-6"

[openclaw.agents.coder]
model = "anthropic/claude-sonnet-4-5"

[openclaw.agents.architect]
model = "anthropic/claude-opus-4-6"

[mail]
domain = "example.com"
smtp_host = "smtp.example.com"

[services.argocd.admin]
user = "operator-admin"
password = "secret"
"""
)

rendered_values = json.loads(
    subprocess.run(
        ["python3", str(SCRIPT), "render-values", "--config", str(custom_argocd_user_config)],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
)
assert rendered_values["argoCd"]["argocd"]["configs"]["cm"]["accounts.operator-admin"] == "apiKey, login"
assert rendered_values["argoCd"]["argocd"]["configs"]["rbac"]["policy.csv"] == "g, operator-admin, role:admin"

blank_service_admin_override_config = write_config(
    """
[providers]
openai_api_key = "test-openai-key"
anthropic_api_key = "test-anthropic-key"

[openclaw.agents.main]
model = "anthropic/claude-sonnet-4-6"

[openclaw.agents.coder]
model = "anthropic/claude-sonnet-4-5"

[openclaw.agents.architect]
model = "anthropic/claude-opus-4-6"

[mail]
domain = "example.com"
smtp_host = "smtp.example.com"

[admin]
username = "fallback-admin"
email = "fallback@example.invalid"
password = "fallback-password"

[services.nextcloud.admin]
user = ""
password = ""

[services.paperless.admin]
user = ""
mail = ""
password = ""
"""
)

shell_vars = subprocess.run(
    ["python3", str(SCRIPT), "shell-vars", "--config", str(blank_service_admin_override_config)],
    check=True,
    capture_output=True,
    text=True,
).stdout
assert "NEXTCLOUD_ADMIN_USER=fallback-admin" in shell_vars
assert "NEXTCLOUD_ADMIN_PASSWORD=fallback-password" in shell_vars
assert "PAPERLESS_ADMIN_USER=fallback-admin" in shell_vars
assert "PAPERLESS_ADMIN_MAIL=fallback@example.invalid" in shell_vars
assert "PAPERLESS_ADMIN_PASSWORD=fallback-password" in shell_vars

missing_provider_for_model_config = write_config(
    """
[providers]
openai_api_key = "test-openai-key"

[openclaw.agents.main]
model = "anthropic/claude-sonnet-4-6"

[openclaw.agents.coder]
model = "anthropic/claude-sonnet-4-5"

[openclaw.agents.architect]
model = "anthropic/claude-opus-4-6"

[mail]
domain = "example.com"
smtp_host = "smtp.example.com"
"""
)

failed = subprocess.run(
    ["python3", str(SCRIPT), "validate", "--config", str(missing_provider_for_model_config)],
    check=False,
    capture_output=True,
    text=True,
)
assert failed.returncode != 0
assert "openclaw.agents.main.model='anthropic/claude-sonnet-4-6' requires ANTHROPIC_API_KEY in [providers]." in failed.stderr

missing_provider_for_fallback_config = write_config(
    """
[providers]
openai_api_key = "test-openai-key"
anthropic_api_key = "test-anthropic-key"

[openclaw.agents.architect]
model = "anthropic/claude-opus-4-6"
fallback_models = ["moonshot/kimi-k2"]

[mail]
domain = "example.com"
smtp_host = "smtp.example.com"
"""
)

failed = subprocess.run(
    ["python3", str(SCRIPT), "validate", "--config", str(missing_provider_for_fallback_config)],
    check=False,
    capture_output=True,
    text=True,
)
assert failed.returncode != 0
assert "openclaw.agents.architect.fallback_models[0]='moonshot/kimi-k2' requires MOONSHOT_API_KEY in [providers]." in failed.stderr

missing_architect_provider_config = write_config(
    """
[providers]
openai_api_key = "test-openai-key"
anthropic_api_key = ""

[openclaw.agents.main]
model = "anthropic/claude-sonnet-4-5"

[openclaw.agents.coder]
model = "anthropic/claude-sonnet-4-5"

[openclaw.agents.architect]
model = "anthropic/claude-opus-4-6"

[mail]
domain = "example.com"
smtp_host = "smtp.example.com"
"""
)

failed = subprocess.run(
    ["python3", str(SCRIPT), "validate", "--config", str(missing_architect_provider_config)],
    check=False,
    capture_output=True,
    text=True,
)
assert failed.returncode != 0
assert "requires ANTHROPIC_API_KEY in [providers]." in failed.stderr

print("bootstrap config tests passed")
