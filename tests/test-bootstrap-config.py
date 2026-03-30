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
model = "anthropic/claude-sonnet-4-6"

[openclaw.agents.coder]
model = "openai/gpt-5.4"

[openclaw.agents.coder.gitea]
username = "coder-bot"
password = "coder-password"

[openclaw.agents.architect]
model = "anthropic/claude-opus-4-6"

[openclaw.agents.watchdog]
model = "anthropic/claude-haiku-4-5"

[hosts]
openclaw = "openclaw.test.internal"
nextcloud = "nextcloud.test.internal"
nextcloud_mcp = "nextcloud-mcp.test.internal"
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
assert "OPENCLAW_MAIN_MODEL=anthropic/claude-sonnet-4-6" in shell_vars
assert "OPENCLAW_CODER_MODEL=openai/gpt-5.4" in shell_vars
assert "OPENCLAW_ARCHITECT_MODEL=anthropic/claude-opus-4-6" in shell_vars
assert "OPENCLAW_WATCHDOG_MODEL=anthropic/claude-haiku-4-5" in shell_vars
assert "GITEA_ADMIN_EMAIL=git@example.invalid" in shell_vars
assert "NEXTCLOUD_ADMIN_USER=test-admin" in shell_vars
assert "NEXTCLOUD_MCP_HOST=nextcloud-mcp.test.internal" in shell_vars
assert "PAPERLESS_ADMIN_MAIL=admin@example.invalid" in shell_vars
assert "OPENCLAW_HOST=openclaw.test.internal" in shell_vars
assert "NEXTCLOUD_PUBLIC_HOST=nextcloud.example.com" in shell_vars
assert "REGISTRY_HOST=registry.test.internal" in shell_vars
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
assert rendered_values["openclaw"]["openclaw"]["agents"]["defaults"]["workspace"] == "/home/node/.openclaw/workspace"
assert rendered_values["openclaw"]["openclaw"]["agents"]["defaults"]["models"] == {
    "anthropic/claude-sonnet-4-6": {"alias": "Main"},
    "openai/gpt-5.4": {"alias": "Coder"},
    "anthropic/claude-opus-4-6": {"alias": "Architect"},
    "anthropic/claude-haiku-4-5": {"alias": "Watchdog"},
}
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][0]["id"] == "main"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][0]["default"] is True
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][0]["model"]["primary"] == "anthropic/claude-sonnet-4-6"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["id"] == "coder"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["workspace"] == "/home/node/.openclaw/workspace-coder"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["model"]["primary"] == "openai/gpt-5.4"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["mode"] == "all"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["image"] == "openclaw-sandbox-coder:bookworm-slim"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["CODER_GITEA_USERNAME"] == "coder-bot"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["CODER_GITEA_HOST"] == "gitea.test.internal"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["CODER_GITEA_BASE_URL"] == "https://gitea.test.internal"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["CODER_GITEA_TEA_LOGIN_NAME"] == "coder"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["CODER_GITEA_TEA_TOKEN_NAME"] == "openclaw-coder-sandbox"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["CODER_REGISTRY_HOST"] == "registry.test.internal"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["CODER_REGISTRY_BASE_URL"] == "https://registry.test.internal"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["CODER_REGISTRY_USERNAME"] == "coder"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["CODER_REGISTRY_NAMESPACE"] == "coder-bot"
assert "export HOME=/workspace" in rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["setupCommand"]
assert 'mkdir -p "${XDG_CONFIG_HOME}/tea" "${XDG_CACHE_HOME}" "${XDG_STATE_HOME}" "${HOME}/.docker"' in rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["setupCommand"]
assert "git config --global user.name" in rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["setupCommand"]
assert "machine gitea.test.internal" in rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["setupCommand"]
assert "tea login add --name coder" in rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["setupCommand"]
assert 'docker login "${CODER_REGISTRY_HOST}"' in rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["setupCommand"]
assert "${CODER_GITEA_USERNAME}" not in rendered_values["openclaw"]["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["setupCommand"]
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][2]["id"] == "architect"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][2]["workspace"] == "/home/node/.openclaw/workspace-architect"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][2]["model"]["primary"] == "anthropic/claude-opus-4-6"
assert "tools" not in rendered_values["openclaw"]["openclaw"]["agents"]["list"][2]
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][3]["id"] == "watchdog"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][3]["workspace"] == "/home/node/.openclaw/workspace-watchdog"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][3]["model"]["primary"] == "anthropic/claude-haiku-4-5"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][3]["sandbox"]["mode"] == "off"
assert rendered_values["openclaw"]["openclaw"]["agents"]["list"][0]["subagents"]["allowAgents"] == ["coder", "architect"]
assert rendered_values["openclaw"]["openclaw"]["tools"]["agentToAgent"]["enabled"] is True
assert rendered_values["openclaw"]["openclaw"]["tools"]["agentToAgent"]["allow"] == ["main", "coder", "architect", "watchdog"]
assert rendered_values["openclaw"]["openclaw"]["tools"]["sessions"]["visibility"] == "all"
assert rendered_values["openclaw"]["workspaceBootstrap"]["enabled"] is True
assert rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["workspace"] == "/home/node/.openclaw/workspace"
assert "openclaw" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["TOOLS.md"]
assert "test-admin" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["USER.md"]
assert "set up direct channels for architect and coder" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["TOOLS.md"]
assert "agent:coder:main" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["TOOLS.md"]
assert "agent:watchdog:main" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["TOOLS.md"]
assert "Treat larger efforts as projects and route them to architect first." in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["TOOLS.md"]
assert "sessions_spawn" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["AGENTS.md"]
assert "Distinguish between small tasks and larger projects" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["AGENTS.md"]
assert "what the user wants to call you" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "sessions_send" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "watchdog monitors" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "treated as projects and sent to architect" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "/Projects/ai-homebase/" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "share `/Projects/` and `/Notes/` with that user" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["main"]["files"]["BOOTSTRAP.md"]
assert "planning and design specialist" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["architect"]["files"]["AGENTS.md"]
assert "Think in projects rather than isolated requests" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["architect"]["files"]["AGENTS.md"]
assert "programming domain" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["AGENTS.md"]
assert "low-cost monitoring and triage specialist" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["watchdog"]["files"]["AGENTS.md"]
assert "agent:main:main" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["watchdog"]["files"]["TOOLS.md"]
assert "Route most findings to main" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["watchdog"]["files"]["TOOLS.md"]
assert "coder-bot" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "test-admin" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["USER.md"]
assert "Tag your shared notes with `#coder`" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "Main owns the shared calendar" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "agent:main:main" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "Use `tea` for repository creation" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "Treat the GitOps repository as a deployment-definition repo" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "Default new cluster-bound images to the in-cluster registry" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "Common tools available include `bash`" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "The Gitea ingress hostname `gitea.test.internal` should resolve from your sandbox runtime." in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "The registry hostname `registry.test.internal` should resolve from your sandbox runtime" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]["TOOLS.md"]
assert "skills/gitea-tea/SKILL.md" not in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]
assert "skills/gitops-homebase/SKILL.md" not in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["coder"]["files"]
assert "Tag your shared notes with `#architect`" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["architect"]["files"]["TOOLS.md"]
assert "Keep project material in predictable documentation folders per project" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["architect"]["files"]["TOOLS.md"]
assert "/Projects/<project-slug>/" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["architect"]["files"]["TOOLS.md"]
assert "/Notes/<project-slug>/" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["architect"]["files"]["TOOLS.md"]
assert "agent:main:main" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["architect"]["files"]["TOOLS.md"]
assert "make sure `/Projects/` and `/Notes/` are shared with them as whole top-level folders" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["architect"]["files"]["TOOLS.md"]
assert "Existing seeded project:" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["architect"]["files"]["MEMORY.md"]
assert "/Projects/ai-homebase/" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["architect"]["files"]["MEMORY.md"]
assert "/Notes/ai-homebase/" in rendered_values["openclaw"]["workspaceBootstrap"]["agents"]["architect"]["files"]["MEMORY.md"]
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

coder_dockerfile = (REPO_ROOT / "images" / "openclaw-sandbox-coder" / "Dockerfile").read_text(encoding="utf-8")
assert "usermod --home /workspace sandbox" in coder_dockerfile
assert "ENV HOME=/workspace" in coder_dockerfile
assert "WORKDIR /workspace" in coder_dockerfile

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

invalid_argocd_user_config = write_config(
    """
[providers]
openai_api_key = "test-openai-key"
anthropic_api_key = "test-anthropic-key"

[openclaw.agents.main]
model = "anthropic/claude-sonnet-4-6"

[openclaw.agents.coder]
model = "openai/gpt-5.4"

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
model = "openai/gpt-5.4"

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
model = "openai/gpt-5.4"

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
model = "openai/gpt-5.4"

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

missing_architect_provider_config = write_config(
    """
[providers]
openai_api_key = "test-openai-key"
anthropic_api_key = ""

[openclaw.agents.main]
model = "openai/gpt-5.4"

[openclaw.agents.coder]
model = "openai/gpt-5.4"

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
assert "openclaw.agents.architect.model='anthropic/claude-opus-4-6' requires ANTHROPIC_API_KEY in [providers]." in failed.stderr

print("bootstrap config tests passed")
