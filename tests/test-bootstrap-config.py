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
brave_api_key = "test-brave-key"

[hosts]
openclaw = "openclaw.test.internal"
nextcloud = "nextcloud.test.internal"
nextcloud_public = "nextcloud.example.com"
gitea = "gitea.test.internal"
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

[services.argocd.admin]
user = "admin"
password = "argocd-admin-password"

[secrets]
vaultwarden_admin_token = "vaultwarden-admin-token"

[gitops]
cluster_name = "lab-cluster"
repo_name = "cluster-gitops"
repo_branch = "main"
repo_private = true
project = "platform-stack"
robot_username = "gitops-bot"
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
assert "BRAVE_API_KEY=test-brave-key" in shell_vars
assert "OPENCLAW_DEFAULT_MODEL=openai/gpt-5.2" in shell_vars
assert "GITEA_ADMIN_EMAIL=git@example.invalid" in shell_vars
assert "NEXTCLOUD_ADMIN_USER=test-admin" in shell_vars
assert "PAPERLESS_ADMIN_MAIL=admin@example.invalid" in shell_vars
assert "OPENCLAW_HOST=openclaw.test.internal" in shell_vars
assert "NEXTCLOUD_PUBLIC_HOST=nextcloud.example.com" in shell_vars
assert "ARGOCD_HOST=argocd.test.internal" in shell_vars
assert "PAPERLESS_HOST=paperless.test.internal" in shell_vars
assert "MAIL_DOMAIN=example.com" in shell_vars
assert "MAIL_SMTP_HOST=smtp.example.com" in shell_vars
assert "MAIL_FROM_LOCALPART=noreply" in shell_vars
assert "VAULTWARDEN_ADMIN_TOKEN=vaultwarden-admin-token" in shell_vars
assert "ARGOCD_ADMIN_USER=admin" in shell_vars
assert "ARGOCD_ADMIN_PASSWORD=argocd-admin-password" in shell_vars
assert "GITOPS_CLUSTER_NAME=lab-cluster" in shell_vars
assert "GITOPS_ROBOT_USERNAME=gitops-bot" in shell_vars
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
assert rendered_values["openclaw"]["secretKeys"]["anthropicApiKey"] == ""
assert rendered_values["openclaw"]["openclaw"]["agents"]["defaults"]["model"]["primary"] == "openai/gpt-5.2"
assert rendered_values["openclaw"]["ingress"]["hosts"][0]["host"] == "openclaw.test.internal"
assert rendered_values["gitea"]["gitea"]["gitea"]["admin"]["existingSecret"] == "gitea-admin-secret"
assert rendered_values["gitea"]["gitea"]["ingress"]["hosts"][0]["host"] == "gitea.test.internal"
assert rendered_values["argoCd"]["argocd"]["server"]["ingress"]["hostname"] == "argocd.test.internal"
assert rendered_values["nextcloud"]["admin"]["user"] == "test-admin"
assert rendered_values["nextcloud"]["ingress"]["private"]["host"] == "nextcloud.test.internal"
assert rendered_values["nextcloud"]["ingress"]["public"]["host"] == "nextcloud.example.com"
assert rendered_values["nextcloud"]["smtp"]["host"] == "platform-stack-postfix-relay"
assert rendered_values["nextcloud"]["smtp"]["domain"] == "example.com"
assert rendered_values["nextcloud"]["trustedDomains"] == ["nextcloud.test.internal", "nextcloud.example.com"]
assert rendered_values["vaultwarden"]["existingSecret"] == "vaultwarden-config-secrets"
assert rendered_values["vaultwarden"]["ingress"]["hosts"][0]["host"] == "vaultwarden.test.internal"
assert rendered_values["vaultwarden"]["ingress"]["tls"][0]["secretName"] == "vaultwarden-tls"
assert rendered_values["vaultwarden"]["smtp"]["from"] == "noreply@example.com"
assert rendered_values["paperlessNgx"]["admin"]["mail"] == "admin@example.invalid"
assert rendered_values["paperlessNgx"]["ingress"]["hosts"][0]["host"] == "paperless.test.internal"
assert rendered_values["global"]["mail"]["smtpHost"] == "smtp.example.com"

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

print("bootstrap config tests passed")
