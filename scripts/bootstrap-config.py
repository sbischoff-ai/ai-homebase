#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import json
import shlex
import sys
from pathlib import Path

import tomllib


PROVIDER_ENV_VARS = (
    "OPENAI_API_KEY",
    "ANTHROPIC_API_KEY",
    "BRAVE_API_KEY",
    "PERPLEXITY_API_KEY",
    "GEMINI_API_KEY",
    "XAI_API_KEY",
    "MOONSHOT_API_KEY",
)

MODEL_PRIORITY = (
    "OPENAI_API_KEY",
    "ANTHROPIC_API_KEY",
    "GEMINI_API_KEY",
    "XAI_API_KEY",
    "MOONSHOT_API_KEY",
)

DEFAULT_MODELS = {
    "OPENAI_API_KEY": "openai/gpt-5.2",
    "ANTHROPIC_API_KEY": "anthropic/claude-opus-4-6",
    "GEMINI_API_KEY": "google/gemini-3-pro-preview",
    "XAI_API_KEY": "xai/grok-4",
    "MOONSHOT_API_KEY": "moonshot/kimi-k2.5",
}

SECRET_KEY_VALUE_NAMES = {
    "OPENAI_API_KEY": "openaiApiKey",
    "ANTHROPIC_API_KEY": "anthropicApiKey",
    "BRAVE_API_KEY": "braveApiKey",
    "PERPLEXITY_API_KEY": "perplexityApiKey",
    "GEMINI_API_KEY": "geminiApiKey",
    "XAI_API_KEY": "xaiApiKey",
    "MOONSHOT_API_KEY": "moonshotApiKey",
}

HOST_KEYS = {
    "openclaw": ("hosts", "openclaw"),
    "nextcloud": ("hosts", "nextcloud"),
    "nextcloud_public": ("hosts", "nextcloud_public"),
    "gitea": ("hosts", "gitea"),
    "argocd": ("hosts", "argocd"),
    "vaultwarden": ("hosts", "vaultwarden"),
    "paperless": ("hosts", "paperless"),
}


def require_string(value: object, context: str) -> str:
    if value is None:
        return ""
    if not isinstance(value, str):
        raise SystemExit(f"{context} must be a string")
    return value


def load_config(config_path: Path) -> dict[str, object]:
    if not config_path.is_file():
        raise SystemExit(
            f"Bootstrap config file not found: {config_path}. Copy bootstrap.example.toml to bootstrap.local.toml first."
        )

    try:
        data = tomllib.loads(config_path.read_text())
    except tomllib.TOMLDecodeError as exc:
        raise SystemExit(f"Invalid bootstrap config TOML in {config_path}: {exc}") from exc

    if not isinstance(data, dict):
        raise SystemExit(f"Bootstrap config root must be a TOML table: {config_path}")
    return data


def nested_string(data: dict[str, object], path: tuple[str, ...], default: str = "") -> str:
    cursor: object = data
    for segment in path:
        if not isinstance(cursor, dict):
            return default
        cursor = cursor.get(segment)
        if cursor is None:
            return default
    return require_string(cursor, ".".join(path))


def provider_values(data: dict[str, object]) -> dict[str, str]:
    providers = {
        "OPENAI_API_KEY": nested_string(data, ("providers", "openai_api_key")),
        "ANTHROPIC_API_KEY": nested_string(data, ("providers", "anthropic_api_key")),
        "BRAVE_API_KEY": nested_string(data, ("providers", "brave_api_key")),
        "PERPLEXITY_API_KEY": nested_string(data, ("providers", "perplexity_api_key")),
        "GEMINI_API_KEY": nested_string(data, ("providers", "gemini_api_key")),
        "XAI_API_KEY": nested_string(data, ("providers", "xai_api_key")),
        "MOONSHOT_API_KEY": nested_string(data, ("providers", "moonshot_api_key")),
    }
    if not any(providers.values()):
        raise SystemExit(
            "At least one supported OpenClaw provider/search key is required in [providers]."
        )
    return providers


def resolved_values(data: dict[str, object]) -> dict[str, str]:
    providers = provider_values(data)

    admin_name = nested_string(data, ("admin", "name"), "Homebase Admin")
    admin_username = nested_string(data, ("admin", "username"), "homebase-admin")
    admin_email = nested_string(data, ("admin", "email"), "admin@example.invalid")
    admin_password = nested_string(data, ("admin", "password"))
    argocd_admin_user = nested_string(data, ("services", "argocd", "admin", "user"), "admin")
    argocd_admin_password = nested_string(data, ("services", "argocd", "admin", "password"))
    mail_domain = nested_string(data, ("mail", "domain"))
    mail_smtp_host = nested_string(data, ("mail", "smtp_host"))
    mail_from_localpart = nested_string(data, ("mail", "from_localpart"), "noreply")
    mail_from_name = nested_string(data, ("mail", "from_name"), "ai-homebase")

    if argocd_admin_user and not re.fullmatch(r"[A-Za-z0-9._-]+", argocd_admin_user):
        raise SystemExit(
            "services.argocd.admin.user must match [A-Za-z0-9._-]+ so it can be rendered safely into Argo CD account and RBAC config."
        )
    if argocd_admin_password and not argocd_admin_user:
        raise SystemExit("services.argocd.admin.user is required when services.argocd.admin.password is set")
    if not mail_domain:
        raise SystemExit("mail.domain is required so the Postfix relay and application sender addresses can be rendered.")
    if not mail_smtp_host:
        raise SystemExit("mail.smtp_host is required so the Postfix relay can present a stable SMTP hostname.")

    values = {
        **providers,
        "OPENCLAW_GATEWAY_TOKEN": nested_string(data, ("secrets", "openclaw_gateway_token")),
        "POSTGRES_ADMIN_PASSWORD": nested_string(data, ("secrets", "postgres_admin_password")),
        "REDIS_PASSWORD": nested_string(data, ("secrets", "redis_password")),
        "GITEA_DB_PASSWORD": nested_string(data, ("secrets", "gitea_db_password")),
        "VAULTWARDEN_DB_PASSWORD": nested_string(data, ("secrets", "vaultwarden_db_password")),
        "VAULTWARDEN_ADMIN_TOKEN": nested_string(data, ("secrets", "vaultwarden_admin_token")),
        "NEXTCLOUD_DB_PASSWORD": nested_string(data, ("secrets", "nextcloud_db_password")),
        "PAPERLESS_DB_PASSWORD": nested_string(data, ("secrets", "paperless_db_password")),
        "PAPERLESS_SECRET_KEY": nested_string(data, ("secrets", "paperless_secret_key")),
        "ADMIN_NAME": admin_name,
        "ADMIN_USERNAME": admin_username,
        "ADMIN_EMAIL": admin_email,
        "ADMIN_PASSWORD": admin_password,
        "GITEA_ADMIN_USERNAME": nested_string(data, ("services", "gitea", "admin", "username"), admin_username),
        "GITEA_ADMIN_EMAIL": nested_string(data, ("services", "gitea", "admin", "email"), admin_email),
        "GITEA_ADMIN_PASSWORD": nested_string(data, ("services", "gitea", "admin", "password"), admin_password),
        "NEXTCLOUD_ADMIN_USER": nested_string(data, ("services", "nextcloud", "admin", "user"), admin_username),
        "NEXTCLOUD_ADMIN_PASSWORD": nested_string(data, ("services", "nextcloud", "admin", "password"), admin_password),
        "PAPERLESS_ADMIN_USER": nested_string(data, ("services", "paperless", "admin", "user"), admin_username),
        "PAPERLESS_ADMIN_MAIL": nested_string(data, ("services", "paperless", "admin", "mail"), admin_email),
        "PAPERLESS_ADMIN_PASSWORD": nested_string(data, ("services", "paperless", "admin", "password"), admin_password),
        "ARGOCD_ADMIN_USER": argocd_admin_user,
        "ARGOCD_ADMIN_PASSWORD": argocd_admin_password,
        "OPENCLAW_HOST": nested_string(data, HOST_KEYS["openclaw"]),
        "NEXTCLOUD_HOST": nested_string(data, HOST_KEYS["nextcloud"]),
        "NEXTCLOUD_PUBLIC_HOST": nested_string(data, HOST_KEYS["nextcloud_public"]),
        "GITEA_HOST": nested_string(data, HOST_KEYS["gitea"]),
        "ARGOCD_HOST": nested_string(data, HOST_KEYS["argocd"]),
        "VAULTWARDEN_HOST": nested_string(data, HOST_KEYS["vaultwarden"]),
        "PAPERLESS_HOST": nested_string(data, HOST_KEYS["paperless"]),
        "MAIL_DOMAIN": mail_domain,
        "MAIL_SMTP_HOST": mail_smtp_host,
        "MAIL_FROM_LOCALPART": mail_from_localpart,
        "MAIL_FROM_NAME": mail_from_name,
        "GITOPS_CLUSTER_NAME": nested_string(data, ("gitops", "cluster_name")),
        "GITOPS_REPO_NAME": nested_string(data, ("gitops", "repo_name"), "cluster-gitops"),
        "GITOPS_REPO_BRANCH": nested_string(data, ("gitops", "repo_branch"), "main"),
        "GITOPS_REPO_PRIVATE": "true",
        "GITOPS_PROJECT": nested_string(data, ("gitops", "project"), "platform-stack"),
        "GITOPS_ROBOT_USERNAME": nested_string(data, ("gitops", "robot_username"), "gitops-bot"),
        "GITOPS_ROBOT_EMAIL": nested_string(data, ("gitops", "robot_email")),
        "GITOPS_ROBOT_PASSWORD": nested_string(data, ("gitops", "robot_password")),
    }
    gitops_table = data.get("gitops")
    if isinstance(gitops_table, dict) and "repo_private" in gitops_table:
        if not isinstance(gitops_table["repo_private"], bool):
            raise SystemExit("gitops.repo_private must be a boolean")
        values["GITOPS_REPO_PRIVATE"] = "true" if gitops_table["repo_private"] else "false"
    if not values["GITOPS_ROBOT_EMAIL"]:
        values["GITOPS_ROBOT_EMAIL"] = f"{values['GITOPS_ROBOT_USERNAME']}@example.invalid"

    default_model = ""
    for env_var in MODEL_PRIORITY:
        if values[env_var]:
            default_model = DEFAULT_MODELS[env_var]
            break
    values["OPENCLAW_DEFAULT_MODEL"] = default_model
    return values


def command_validate(args: argparse.Namespace) -> int:
    resolved_values(load_config(args.config))
    print(f"bootstrap config is valid: {args.config}")
    return 0


def command_shell_vars(args: argparse.Namespace) -> int:
    values = resolved_values(load_config(args.config))
    for key in sorted(values):
        print(f"{key}={shlex.quote(values[key])}")
    return 0


def command_render_values(args: argparse.Namespace) -> int:
    values = resolved_values(load_config(args.config))
    openclaw: dict[str, object] = {
        "secretKeys": {
            "gatewayToken": "OPENCLAW_GATEWAY_TOKEN",
            **{
                secret_key_name: env_var if values[env_var] else ""
                for env_var, secret_key_name in SECRET_KEY_VALUE_NAMES.items()
            },
        }
    }
    global_hosts = {
        "openclaw": values["OPENCLAW_HOST"],
        "nextcloud": values["NEXTCLOUD_HOST"],
        "gitea": values["GITEA_HOST"],
        "argocd": values["ARGOCD_HOST"],
        "vaultwarden": values["VAULTWARDEN_HOST"],
        "paperlessNgx": values["PAPERLESS_HOST"],
    }
    full_mail_from = f"{values['MAIL_FROM_LOCALPART']}@{values['MAIL_DOMAIN']}"
    if values["OPENCLAW_DEFAULT_MODEL"]:
        openclaw["openclaw"] = {
            "agents": {
                "defaults": {
                    "model": {
                        "primary": values["OPENCLAW_DEFAULT_MODEL"],
                    }
                }
            }
        }
    if values["OPENCLAW_HOST"]:
        openclaw.setdefault("ingress", {})
        openclaw["ingress"]["hosts"] = [
            {
                "host": values["OPENCLAW_HOST"],
                "paths": [{"path": "/", "pathType": "Prefix"}],
            }
        ]
        openclaw["ingress"]["tls"] = [
            {
                "secretName": "openclaw-tls",
                "hosts": [values["OPENCLAW_HOST"]],
            }
        ]
        openclaw.setdefault("openclaw", {}).setdefault("gateway", {}).setdefault("controlUi", {})[
            "allowedOrigins"
        ] = [f"https://{values['OPENCLAW_HOST']}"]

    rendered: dict[str, object] = {
        "global": {
            "hosts": {key: value for key, value in global_hosts.items() if value},
            "mail": {
                "domain": values["MAIL_DOMAIN"],
                "smtpHost": values["MAIL_SMTP_HOST"],
                "fromLocalpart": values["MAIL_FROM_LOCALPART"],
                "fromName": values["MAIL_FROM_NAME"],
                "fromAddress": full_mail_from,
            },
        },
        "openclaw": openclaw,
        "gitea": {
            "gitea": {
                "ingress": (
                    {
                        "hosts": [
                            {
                                "host": values["GITEA_HOST"],
                                "paths": [{"path": "/", "pathType": "Prefix"}],
                            }
                        ]
                    }
                    if values["GITEA_HOST"]
                    else {}
                ),
                "gitea": {
                    "admin": {
                        "username": values["GITEA_ADMIN_USERNAME"],
                        "email": values["GITEA_ADMIN_EMAIL"],
                        "existingSecret": "gitea-admin-secret",
                    }
                }
            }
        },
        "argoCd": {
            "argocd": {
                "server": {
                    "ingress": (
                        {
                            "enabled": True,
                            "hostname": values["ARGOCD_HOST"],
                            "tls": False,
                        }
                        if values["ARGOCD_HOST"]
                        else {}
                    )
                }
            }
        },
        "nextcloud": {
            "ingress": (
                {
                    "private": {"host": values["NEXTCLOUD_HOST"]},
                    "public": {"host": values["NEXTCLOUD_PUBLIC_HOST"]},
                }
                if values["NEXTCLOUD_HOST"] or values["NEXTCLOUD_PUBLIC_HOST"]
                else {}
            ),
            "admin": {
                "user": values["NEXTCLOUD_ADMIN_USER"],
            },
            "smtp": {
                "host": "platform-stack-postfix-relay",
                "port": 587,
                "secure": "",
                "fromAddress": values["MAIL_FROM_LOCALPART"],
                "domain": values["MAIL_DOMAIN"],
            },
            "trustedDomains": [
                host for host in (values["NEXTCLOUD_HOST"], values["NEXTCLOUD_PUBLIC_HOST"]) if host
            ],
        },
        "vaultwarden": {
            "existingSecret": "vaultwarden-config-secrets",
            "smtp": {
                "host": "platform-stack-postfix-relay",
                "port": 587,
                "from": full_mail_from,
                "fromName": values["MAIL_FROM_NAME"],
                "security": "off",
            },
            "ingress": (
                {
                    "annotations": {
                        "cert-manager.io/cluster-issuer": "platform-stack-root-ca",
                    },
                    "hosts": [
                        {
                            "host": values["VAULTWARDEN_HOST"],
                            "paths": [{"path": "/", "pathType": "Prefix"}],
                        }
                    ],
                    "tls": [
                        {
                            "secretName": "vaultwarden-tls",
                            "hosts": [values["VAULTWARDEN_HOST"]],
                        }
                    ],
                }
                if values["VAULTWARDEN_HOST"]
                else {}
            ),
        },
        "paperlessNgx": {
            "ingress": (
                {
                    "hosts": [
                        {
                            "host": values["PAPERLESS_HOST"],
                            "paths": [{"path": "/", "pathType": "Prefix"}],
                        }
                    ]
                }
                if values["PAPERLESS_HOST"]
                else {}
            ),
            "admin": {
                "user": values["PAPERLESS_ADMIN_USER"],
                "mail": values["PAPERLESS_ADMIN_MAIL"],
            }
        },
    }
    if values["ARGOCD_ADMIN_USER"] and values["ARGOCD_ADMIN_USER"] != "admin":
        rendered["argoCd"]["argocd"].setdefault("configs", {}).setdefault("cm", {})[
            f"accounts.{values['ARGOCD_ADMIN_USER']}"
        ] = "apiKey, login"
        rendered["argoCd"]["argocd"].setdefault("configs", {}).setdefault("rbac", {})[
            "policy.csv"
        ] = f"g, {values['ARGOCD_ADMIN_USER']}, role:admin"

    json.dump(rendered, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Bootstrap config helper")
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate_parser = subparsers.add_parser("validate")
    validate_parser.add_argument("--config", type=Path, required=True)
    validate_parser.set_defaults(func=command_validate)

    shell_vars_parser = subparsers.add_parser("shell-vars")
    shell_vars_parser.add_argument("--config", type=Path, required=True)
    shell_vars_parser.set_defaults(func=command_shell_vars)

    render_values_parser = subparsers.add_parser("render-values")
    render_values_parser.add_argument("--config", type=Path, required=True)
    render_values_parser.set_defaults(func=command_render_values)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
