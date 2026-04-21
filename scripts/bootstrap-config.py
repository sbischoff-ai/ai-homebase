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

DEFAULT_MAIN_MODEL = "anthropic/claude-sonnet-4-6"
DEFAULT_MAIN_FALLBACK_MODELS = ["openai/gpt-5.4", "google/gemini-3.1-pro-preview"]
DEFAULT_CODER_MODEL = "openai/gpt-5.4"
DEFAULT_CODER_FALLBACK_MODELS = ["anthropic/claude-sonnet-4-6", "google/gemini-3.1-pro-preview"]
# `openai/gpt-5.3-codex` remains a valid override for higher code quality
# at roughly 3x the cost ($2.275 / $18.20 per 1M tokens).
DEFAULT_CODEX_MODEL = "openai/gpt-5.4-mini"
DEFAULT_ARCHITECT_MODEL = "openai/gpt-5.4"
DEFAULT_ARCHITECT_FALLBACK_MODELS = ["anthropic/claude-sonnet-4-6", "google/gemini-3.1-pro-preview"]
DEFAULT_ARCHIVIST_MODEL = "openai/gpt-5.4-mini"
DEFAULT_ARCHIVIST_FALLBACK_MODELS = ["anthropic/claude-sonnet-4-6", "google/gemini-3.1-flash-lite-preview"]
DEFAULT_WATCHDOG_MODEL = "openai/gpt-5.4-nano"
DEFAULT_WATCHDOG_FALLBACK_MODELS = ["google/gemini-3.1-flash-lite-preview", "anthropic/claude-haiku-4-5"]
DEFAULT_AUDITOR_MODEL = "anthropic/claude-opus-4-7"
DEFAULT_AUDITOR_FALLBACK_MODELS = ["openai/gpt-5.4", "google/gemini-3.1-pro-preview"]
SHARED_MCP_BRIDGE_PATH = "/opt/openclaw-runtime/mcp/mcp-http-bridge.mjs"
SANDBOX_CA_BUNDLE_PATH = "/workspace/.openclaw-runtime/ai-homebase-ca-bundle.crt"
NEXTCLOUD_MCP_USERNAME = "openclaw"
DEFAULT_CODER_GITEA_USERNAME = "coder"
DEFAULT_REVIEWER_GITEA_USERNAME = "reviewer"
DEFAULT_REGISTRY_USERNAME = "coder"
DEFAULT_SANDBOX_IMAGES_REPO_NAME = "openclaw-sandbox-images"
DEFAULT_GITEA_ACTIONS_RUNNER_VM_NAME = "gitea-actions-runner"
DEFAULT_GITEA_ACTIONS_RUNNER_HOST_ALIAS = "gitea-actions-runner.homebase.internal"
DEFAULT_GITEA_ACTIONS_RUNNER_SSH_PORT = "2223"
DEFAULT_GITEA_ACTIONS_RUNNER_LABELS = ["linux-amd64", "homebase-coder"]
BUNDLED_SKILLS = [
    "weather",
    "healthcheck",
    "node-connect",
    "skill-creator",
    "session-logs",
    "tmux",
    "summarize",
    "github",
]

AGENT_SKILLS = {
    "main": [
        "handoff-specialist-work",
        "manage-worker-lifecycle",
        "bind-channels",
        "coordinate-in-nextcloud",
        "record-memory-and-coordination-status",
        "track-budget",
        "healthcheck",
        "node-connect",
        "skill-creator",
        "session-logs",
        "weather",
        "summarize",
    ],
    "coder": [
        "manage-gitea-gitops-and-registry",
        "run-codex-and-log-usage",
        "update-implementation-notes",
        "github",
        "tmux",
    ],
    "architect": [
        "plan-projects",
        "package-worker-definitions",
        "deliver-design",
        "gitea-browse",
        "skill-creator",
        "session-logs",
        "summarize",
        "github",
    ],
    "archivist": [
        "curate-memgraph",
        "groom-knowledge-graph",
        "map-context-and-link-evidence",
        "use-nextcloud-docs-for-graph-work",
        "session-logs",
        "summarize",
    ],
    "watchdog": [
        "classify-severity-and-escalate",
        "manage-nextcloud-incidents",
        "check-heartbeat-and-budget",
        "healthcheck",
        "node-connect",
        "session-logs",
    ],
    "auditor": [
        "classify-review-mode",
        "manage-review-packets",
        "format-verdict",
        "gitea-browse",
        "session-logs",
        "summarize",
        "github",
    ],
}

AGENT_TOOL_DENY = {
    "architect": ["tts", "image_generate", "canvas"],
    "archivist": ["tts", "image_generate", "canvas", "browser"],
    "watchdog": [
        "image_generate",
        "canvas",
        "tts",
        "image",
        "browser",
        "sessions_spawn",
        "agents_list",
        "subagents",
    ],
    "auditor": ["tts", "image_generate", "canvas"],
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
    "nextcloud_mcp": ("hosts", "nextcloud_mcp"),
    "qdrant": ("hosts", "qdrant"),
    "qdrant_mcp": ("hosts", "qdrant_mcp"),
    "memgraph": ("hosts", "memgraph"),
    "memgraph_lab": ("hosts", "memgraph_lab"),
    "nextcloud_public": ("hosts", "nextcloud_public"),
    "gitea": ("hosts", "gitea"),
    "registry": ("hosts", "registry"),
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


def nested_value(data: dict[str, object], path: tuple[str, ...], default: object | None = None) -> object | None:
    cursor: object = data
    for segment in path:
        if not isinstance(cursor, dict):
            return default
        if segment not in cursor:
            return default
        cursor = cursor[segment]
    return cursor


def nested_nonempty_string(data: dict[str, object], path: tuple[str, ...], default: str = "") -> str:
    value = nested_string(data, path, default)
    if value == "":
        return default
    return value


def nested_bool(data: dict[str, object], path: tuple[str, ...], default: bool = False) -> bool:
    value = nested_value(data, path, default)
    if isinstance(value, bool):
        return value
    raise SystemExit(f"{'.'.join(path)} must be a boolean")


def require_string_list(value: object, context: str) -> list[str]:
    if value is None:
        return []
    if not isinstance(value, list):
        raise SystemExit(f"{context} must be an array of strings")
    normalized: list[str] = []
    for index, item in enumerate(value):
        item_context = f"{context}[{index}]"
        item_value = require_string(item, item_context).strip()
        if item_value == "":
            raise SystemExit(f"{item_context} must not be empty")
        normalized.append(item_value)
    return normalized


def registry_image_ref(registry_host: str, namespace: str, image_name: str, tag: str = "trixie-slim") -> str:
    if not registry_host or not namespace:
        return f"{image_name}:{tag}"
    return f"{registry_host}/{namespace}/{image_name}:{tag}"


NEXTCLOUD_PROJECT_BOOTSTRAP_FILES = [
    "overview.md",
    "multi-agent-topology.md",
    "gitops-workflow.md",
    "cluster-architecture.md",
    "project-documentation-model.md",
    "worker-design-guide.md",
    "qdrant-memory-schema.md",
    "knowledge-graph-schema.md",
    "budget-policy.md",
    "decisions.md",
    "automation-backlog.md",
    "archivist-grooming-log.md",
    "watchdog-status-log.md",
    "incidents/README.md",
    "audit-reports/README.md",
    "coordination-status.json",
    "codex-usage/.gitkeep",
    "audit-log.md",
    "baselines.md",
    "escalation-rules.md",
]


def nextcloud_project_bootstrap_values() -> list[dict[str, object]]:
    return [
        {
            "slug": "ai-homebase",
            "ownerUsername": NEXTCLOUD_MCP_USERNAME,
            "projectsFilesDir": "bootstrap-content/ai-homebase/projects",
            "projectsFiles": [{"path": path} for path in NEXTCLOUD_PROJECT_BOOTSTRAP_FILES],
        }
    ]


def workspace_bootstrap_values() -> dict[str, object]:
    return {
        "enabled": True,
        "agents": {
            "main": {
                "workspace": "/home/node/.openclaw/workspace",
                "filesDir": "workspaces/main",
            },
            "coder": {
                "workspace": "/home/node/.openclaw/workspace-coder",
                "filesDir": "workspaces/coder",
            },
            "architect": {
                "workspace": "/home/node/.openclaw/workspace-architect",
                "filesDir": "workspaces/architect",
            },
            "archivist": {
                "workspace": "/home/node/.openclaw/workspace-archivist",
                "filesDir": "workspaces/archivist",
            },
            "watchdog": {
                "workspace": "/home/node/.openclaw/workspace-watchdog",
                "filesDir": "workspaces/watchdog",
            },
            "auditor": {
                "workspace": "/home/node/.openclaw/workspace-auditor",
                "filesDir": "workspaces/auditor",
            },
            "worker-template": {
                "workspace": "/home/node/.openclaw/worker-template",
                "filesDir": "workspaces/worker-template",
            },
        },
    }


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
    if not providers["OPENAI_API_KEY"]:
        raise SystemExit("OPENAI_API_KEY is required in [providers] for the bootstrapped coder Codex workflow.")
    return providers


def provider_env_var_for_model(model: str) -> str:
    provider = model.partition("/")[0].strip().lower()
    provider_to_env = {
        "openai": "OPENAI_API_KEY",
        "anthropic": "ANTHROPIC_API_KEY",
        "google": "GEMINI_API_KEY",
        "xai": "XAI_API_KEY",
        "moonshot": "MOONSHOT_API_KEY",
    }
    env_var = provider_to_env.get(provider, "")
    if env_var:
        return env_var
    raise SystemExit(
        "Unsupported OpenClaw bootstrap model provider "
        f"{provider!r} in {model!r}; supported providers for bootstrap-managed agent models are "
        "openai, anthropic, google, xai, and moonshot."
    )


def unique_models(models: list[str]) -> list[str]:
    seen: set[str] = set()
    unique: list[str] = []
    for model in models:
        if model in seen:
            continue
        seen.add(model)
        unique.append(model)
    return unique


def resolve_agent_model_config(
    data: dict[str, object],
    agent_id: str,
    default_primary: str,
    default_fallbacks: list[str],
) -> dict[str, object]:
    primary = nested_nonempty_string(data, ("openclaw", "agents", agent_id, "model"), default_primary)
    fallback_value = nested_value(data, ("openclaw", "agents", agent_id, "fallback_models"))
    if fallback_value is None:
        fallbacks = list(default_fallbacks)
    else:
        fallbacks = require_string_list(fallback_value, f"openclaw.agents.{agent_id}.fallback_models")
    fallbacks = [model for model in unique_models(fallbacks) if model != primary]
    return {
        "primary": primary,
        "fallbacks": fallbacks,
    }


def resolve_agent_models(data: dict[str, object], providers: dict[str, str]) -> dict[str, dict[str, object]]:
    agent_models = {
        "main": resolve_agent_model_config(data, "main", DEFAULT_MAIN_MODEL, DEFAULT_MAIN_FALLBACK_MODELS),
        "coder": resolve_agent_model_config(data, "coder", DEFAULT_CODER_MODEL, DEFAULT_CODER_FALLBACK_MODELS),
        "architect": resolve_agent_model_config(
            data, "architect", DEFAULT_ARCHITECT_MODEL, DEFAULT_ARCHITECT_FALLBACK_MODELS
        ),
        "archivist": resolve_agent_model_config(
            data, "archivist", DEFAULT_ARCHIVIST_MODEL, DEFAULT_ARCHIVIST_FALLBACK_MODELS
        ),
        "watchdog": resolve_agent_model_config(data, "watchdog", DEFAULT_WATCHDOG_MODEL, DEFAULT_WATCHDOG_FALLBACK_MODELS),
        "auditor": resolve_agent_model_config(data, "auditor", DEFAULT_AUDITOR_MODEL, DEFAULT_AUDITOR_FALLBACK_MODELS),
    }
    for agent_id, model_config in agent_models.items():
        primary = require_string(model_config["primary"], f"openclaw.agents.{agent_id}.model")
        models_to_validate = [primary, *require_string_list(model_config["fallbacks"], f"openclaw.agents.{agent_id}.fallback_models")]
        for index, model_value in enumerate(models_to_validate):
            model_key = f"openclaw.agents.{agent_id}.model" if index == 0 else f"openclaw.agents.{agent_id}.fallback_models[{index - 1}]"
            if "/" not in model_value:
                raise SystemExit(
                    f"{model_key} must use the OpenClaw provider/model form, for example openai/gpt-5.4."
                )
            provider_env_var = provider_env_var_for_model(model_value)
            if not providers.get(provider_env_var, ""):
                raise SystemExit(f"{model_key}={model_value!r} requires {provider_env_var} in [providers].")
    return agent_models


def resolved_values(data: dict[str, object]) -> dict[str, str]:
    providers = provider_values(data)
    agent_models = resolve_agent_models(data, providers)
    main_model = require_string(agent_models["main"]["primary"], "openclaw.agents.main.model")
    coder_model = require_string(agent_models["coder"]["primary"], "openclaw.agents.coder.model")
    architect_model = require_string(agent_models["architect"]["primary"], "openclaw.agents.architect.model")
    archivist_model = require_string(agent_models["archivist"]["primary"], "openclaw.agents.archivist.model")
    watchdog_model = require_string(agent_models["watchdog"]["primary"], "openclaw.agents.watchdog.model")
    auditor_model = require_string(agent_models["auditor"]["primary"], "openclaw.agents.auditor.model")
    codex_model = nested_nonempty_string(data, ("openclaw", "agents", "coder", "codex_model"), DEFAULT_CODEX_MODEL)

    admin_name = nested_string(data, ("admin", "name"), "Homebase Admin")
    admin_username = nested_string(data, ("admin", "username"), "homebase-admin")
    admin_email = nested_string(data, ("admin", "email"), "admin@example.invalid")
    admin_password = nested_string(data, ("admin", "password"))
    gitea_user_username = nested_nonempty_string(data, ("services", "gitea", "admin", "username"), admin_username)
    argocd_admin_user = nested_nonempty_string(data, ("services", "argocd", "admin", "user"), "admin")
    argocd_admin_password = nested_string(data, ("services", "argocd", "admin", "password"))
    mail_domain = nested_string(data, ("mail", "domain"))
    mail_smtp_host = nested_string(data, ("mail", "smtp_host"))
    mail_from_localpart = nested_string(data, ("mail", "from_localpart"), "noreply")
    mail_from_name = nested_string(data, ("mail", "from_name"), "ai-homebase")
    coder_gitea_username = nested_nonempty_string(
        data,
        ("openclaw", "agents", "coder", "gitea", "username"),
        nested_string(data, ("gitops", "robot_username"), DEFAULT_CODER_GITEA_USERNAME),
    )
    coder_gitea_email = nested_nonempty_string(
        data,
        ("openclaw", "agents", "coder", "gitea", "email"),
        nested_string(data, ("gitops", "robot_email")),
    )
    coder_gitea_password = nested_string(data, ("openclaw", "agents", "coder", "gitea", "password"))
    if not coder_gitea_password:
        coder_gitea_password = nested_string(data, ("gitops", "robot_password"))
    reviewer_gitea_username = nested_nonempty_string(
        data,
        ("openclaw", "agents", "reviewer", "gitea", "username"),
        DEFAULT_REVIEWER_GITEA_USERNAME,
    )
    reviewer_gitea_email = nested_nonempty_string(
        data,
        ("openclaw", "agents", "reviewer", "gitea", "email"),
        "",
    )
    reviewer_gitea_password = nested_string(data, ("openclaw", "agents", "reviewer", "gitea", "password"))
    registry_username = nested_nonempty_string(
        data,
        ("services", "registry", "auth", "username"),
        DEFAULT_REGISTRY_USERNAME,
    )
    registry_password = nested_string(data, ("services", "registry", "auth", "password"))
    github_token = nested_string(data, ("secrets", "github_token"))
    gitea_actions_enabled = nested_bool(data, ("services", "gitea", "actions", "enabled"), True)
    gitea_actions_runner_vm_name = nested_nonempty_string(
        data,
        ("services", "gitea", "actions", "vm_name"),
        DEFAULT_GITEA_ACTIONS_RUNNER_VM_NAME,
    )
    gitea_actions_runner_host_alias = nested_nonempty_string(
        data,
        ("services", "gitea", "actions", "host_alias"),
        DEFAULT_GITEA_ACTIONS_RUNNER_HOST_ALIAS,
    )
    gitea_actions_runner_ssh_port_value = nested_value(
        data,
        ("services", "gitea", "actions", "ssh_port"),
        DEFAULT_GITEA_ACTIONS_RUNNER_SSH_PORT,
    )
    if isinstance(gitea_actions_runner_ssh_port_value, int):
        gitea_actions_runner_ssh_port = str(gitea_actions_runner_ssh_port_value)
    elif isinstance(gitea_actions_runner_ssh_port_value, str):
        gitea_actions_runner_ssh_port = gitea_actions_runner_ssh_port_value
    else:
        raise SystemExit("services.gitea.actions.ssh_port must be an integer TCP port.")
    gitea_actions_runner_labels = require_string_list(
        nested_value(data, ("services", "gitea", "actions", "labels")) or list(DEFAULT_GITEA_ACTIONS_RUNNER_LABELS),
        "services.gitea.actions.labels",
    )

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
    if not re.fullmatch(r"[0-9]+", gitea_actions_runner_ssh_port):
        raise SystemExit("services.gitea.actions.ssh_port must be an integer TCP port.")
    if any(":" in label or "," in label for label in gitea_actions_runner_labels):
        raise SystemExit("services.gitea.actions.labels must contain plain label names without ':' or ','.")
    if "/" not in codex_model:
        raise SystemExit(
            "openclaw.agents.coder.codex_model must use the OpenClaw provider/model form, for example openai/gpt-5.4-mini."
        )
    values = {
        **providers,
        "OPENCLAW_GATEWAY_TOKEN": nested_string(data, ("secrets", "openclaw_gateway_token")),
        "POSTGRES_ADMIN_PASSWORD": nested_string(data, ("secrets", "postgres_admin_password")),
        "REDIS_PASSWORD": nested_string(data, ("secrets", "redis_password")),
        "GITEA_DB_PASSWORD": nested_string(data, ("secrets", "gitea_db_password")),
        "VAULTWARDEN_DB_PASSWORD": nested_string(data, ("secrets", "vaultwarden_db_password")),
        "VAULTWARDEN_ADMIN_TOKEN": nested_string(data, ("secrets", "vaultwarden_admin_token")),
        "NEXTCLOUD_DB_PASSWORD": nested_string(data, ("secrets", "nextcloud_db_password")),
        "OPENCLAW_NEXTCLOUD_MCP_PASSWORD": nested_string(data, ("secrets", "openclaw_nextcloud_mcp_password")),
        "PAPERLESS_DB_PASSWORD": nested_string(data, ("secrets", "paperless_db_password")),
        "PAPERLESS_SECRET_KEY": nested_string(data, ("secrets", "paperless_secret_key")),
        "GITHUB_TOKEN": github_token,
        "ADMIN_NAME": admin_name,
        "ADMIN_USERNAME": admin_username,
        "ADMIN_EMAIL": admin_email,
        "ADMIN_PASSWORD": admin_password,
        "GITEA_ADMIN_USERNAME": nested_nonempty_string(data, ("services", "gitea", "admin", "username"), admin_username),
        "GITEA_ADMIN_EMAIL": nested_nonempty_string(data, ("services", "gitea", "admin", "email"), admin_email),
        "GITEA_ADMIN_PASSWORD": nested_nonempty_string(data, ("services", "gitea", "admin", "password"), admin_password),
        "GITEA_USER_USERNAME": gitea_user_username,
        "NEXTCLOUD_ADMIN_USER": nested_nonempty_string(data, ("services", "nextcloud", "admin", "user"), admin_username),
        "NEXTCLOUD_ADMIN_PASSWORD": nested_nonempty_string(data, ("services", "nextcloud", "admin", "password"), admin_password),
        "PAPERLESS_ADMIN_USER": nested_nonempty_string(data, ("services", "paperless", "admin", "user"), admin_username),
        "PAPERLESS_ADMIN_MAIL": nested_nonempty_string(data, ("services", "paperless", "admin", "mail"), admin_email),
        "PAPERLESS_ADMIN_PASSWORD": nested_nonempty_string(data, ("services", "paperless", "admin", "password"), admin_password),
        "ARGOCD_ADMIN_USER": argocd_admin_user,
        "ARGOCD_ADMIN_PASSWORD": argocd_admin_password,
        "OPENCLAW_HOST": nested_string(data, HOST_KEYS["openclaw"]),
        "NEXTCLOUD_HOST": nested_string(data, HOST_KEYS["nextcloud"]),
        "NEXTCLOUD_MCP_HOST": nested_string(data, HOST_KEYS["nextcloud_mcp"]),
        "NEXTCLOUD_PUBLIC_HOST": nested_string(data, HOST_KEYS["nextcloud_public"]),
        "GITEA_HOST": nested_string(data, HOST_KEYS["gitea"]),
        "QDRANT_HOST": nested_string(data, HOST_KEYS["qdrant"]),
        "QDRANT_MCP_HOST": nested_string(data, HOST_KEYS["qdrant_mcp"]),
        "MEMGRAPH_HOST": nested_string(data, HOST_KEYS["memgraph"]),
        "MEMGRAPH_LAB_HOST": nested_string(data, HOST_KEYS["memgraph_lab"]),
        "REGISTRY_HOST": nested_string(data, HOST_KEYS["registry"]),
        "ARGOCD_HOST": nested_string(data, HOST_KEYS["argocd"]),
        "VAULTWARDEN_HOST": nested_string(data, HOST_KEYS["vaultwarden"]),
        "PAPERLESS_HOST": nested_string(data, HOST_KEYS["paperless"]),
        "MAIL_DOMAIN": mail_domain,
        "MAIL_SMTP_HOST": mail_smtp_host,
        "MAIL_FROM_LOCALPART": mail_from_localpart,
        "MAIL_FROM_NAME": mail_from_name,
        "GITOPS_CLUSTER_NAME": nested_string(data, ("gitops", "cluster_name")),
        "GITOPS_REPO_NAME": nested_string(data, ("gitops", "repo_name"), "cluster-gitops"),
        "SANDBOX_IMAGES_REPO_NAME": nested_string(
            data, ("gitops", "sandbox_images_repo_name"), DEFAULT_SANDBOX_IMAGES_REPO_NAME
        ),
        "GITOPS_REPO_BRANCH": nested_string(data, ("gitops", "repo_branch"), "main"),
        "GITOPS_REPO_PRIVATE": "true",
        "GITOPS_PROJECT": nested_string(data, ("gitops", "project"), "platform-stack"),
        "CODER_GITEA_USERNAME": coder_gitea_username,
        "CODER_GITEA_EMAIL": coder_gitea_email,
        "CODER_GITEA_PASSWORD": coder_gitea_password,
        "REVIEWER_GITEA_USERNAME": reviewer_gitea_username,
        "REVIEWER_GITEA_EMAIL": reviewer_gitea_email,
        "REVIEWER_GITEA_PASSWORD": reviewer_gitea_password,
        "REGISTRY_USERNAME": registry_username,
        "REGISTRY_PASSWORD": registry_password,
        "GITEA_ACTIONS_ENABLED": "true" if gitea_actions_enabled else "false",
        "GITEA_ACTIONS_RUNNER_VM_NAME": gitea_actions_runner_vm_name,
        "GITEA_ACTIONS_RUNNER_HOST_ALIAS": gitea_actions_runner_host_alias,
        "GITEA_ACTIONS_RUNNER_SSH_PORT": gitea_actions_runner_ssh_port,
        "GITEA_ACTIONS_RUNNER_LABEL_NAMES": ",".join(gitea_actions_runner_labels),
        "CODEX_MODEL": codex_model,
        "CODEX_DEFAULT_MODEL": codex_model.split("/", 1)[1],
        "OPENCLAW_MAIN_MODEL": main_model,
        "OPENCLAW_CODER_MODEL": coder_model,
        "OPENCLAW_ARCHITECT_MODEL": architect_model,
        "OPENCLAW_ARCHIVIST_MODEL": archivist_model,
        "OPENCLAW_WATCHDOG_MODEL": watchdog_model,
        "OPENCLAW_AUDITOR_MODEL": auditor_model,
    }
    gitops_table = data.get("gitops")
    if isinstance(gitops_table, dict) and "repo_private" in gitops_table:
        if not isinstance(gitops_table["repo_private"], bool):
            raise SystemExit("gitops.repo_private must be a boolean")
        values["GITOPS_REPO_PRIVATE"] = "true" if gitops_table["repo_private"] else "false"
    if not values["CODER_GITEA_EMAIL"]:
        values["CODER_GITEA_EMAIL"] = f"{values['CODER_GITEA_USERNAME']}@example.invalid"
    if not values["REVIEWER_GITEA_EMAIL"]:
        values["REVIEWER_GITEA_EMAIL"] = f"{values['REVIEWER_GITEA_USERNAME']}@example.invalid"
    values["OPENCLAW_DEFAULT_SANDBOX_IMAGE"] = registry_image_ref(
        values["REGISTRY_HOST"], values["CODER_GITEA_USERNAME"], "openclaw-sandbox"
    )
    values["OPENCLAW_CODER_SANDBOX_IMAGE"] = registry_image_ref(
        values["REGISTRY_HOST"], values["CODER_GITEA_USERNAME"], "openclaw-sandbox-coder"
    )
    values["GITEA_ACTIONS_JOB_IMAGE"] = registry_image_ref(
        values["REGISTRY_HOST"], values["CODER_GITEA_USERNAME"], "gitea-actions-job"
    )
    values["GITEA_ACTIONS_RUNNER_LABELS"] = ",".join(
        f"{label}:docker://{values['GITEA_ACTIONS_JOB_IMAGE']}" for label in gitea_actions_runner_labels
    )
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
    data = load_config(args.config)
    values = resolved_values(data)
    agent_models = resolve_agent_models(data, provider_values(data))
    workspace_bootstrap = workspace_bootstrap_values()
    allowed_models: dict[str, dict[str, str]] = {}
    for agent_id in ("main", "coder", "architect", "archivist", "watchdog", "auditor"):
        model_config = agent_models[agent_id]
        for model_id in [require_string(model_config["primary"], f"openclaw.agents.{agent_id}.model"), *require_string_list(model_config["fallbacks"], f"openclaw.agents.{agent_id}.fallback_models")]:
            if model_id not in allowed_models:
                allowed_models[model_id] = {"alias": model_id.split("/", 1)[1]}
    openclaw: dict[str, object] = {
        "secretKeys": {
            "gatewayToken": "OPENCLAW_GATEWAY_TOKEN",
            **{
                secret_key_name: env_var if values[env_var] else ""
                for env_var, secret_key_name in SECRET_KEY_VALUE_NAMES.items()
            },
        }
    }
    if values["GITHUB_TOKEN"]:
        openclaw["secretKeys"]["githubToken"] = "GITHUB_TOKEN"
    global_hosts = {
        "openclaw": values["OPENCLAW_HOST"],
        "nextcloud": values["NEXTCLOUD_HOST"],
        "nextcloudMcp": values["NEXTCLOUD_MCP_HOST"],
        "qdrant": values["QDRANT_HOST"],
        "qdrantMcp": values["QDRANT_MCP_HOST"],
        "memgraph": values["MEMGRAPH_HOST"],
        "memgraphLab": values["MEMGRAPH_LAB_HOST"],
        "gitea": values["GITEA_HOST"],
        "registry": values["REGISTRY_HOST"],
        "argocd": values["ARGOCD_HOST"],
        "vaultwarden": values["VAULTWARDEN_HOST"],
        "paperlessNgx": values["PAPERLESS_HOST"],
    }
    full_mail_from = f"{values['MAIL_FROM_LOCALPART']}@{values['MAIL_DOMAIN']}"
    gitea_scheme = "http" if values["GITEA_HOST"].endswith(".localtest.me") else "https"
    gitea_base_url = f"{gitea_scheme}://{values['GITEA_HOST']}"
    internal_gitea_service_host = '{{ printf "%s-gitea-http.%s.svc.cluster.local" .Release.Name .Release.Namespace }}'
    internal_gitea_service_base_url = f"http://{internal_gitea_service_host}:3000"
    qdrant_scheme = "http" if values["QDRANT_HOST"].endswith(".localtest.me") else "https"
    qdrant_sandbox_url = f"{qdrant_scheme}://{values['QDRANT_HOST']}" if values["QDRANT_HOST"] else ""
    openclaw["openclaw"] = {
        "skills": {
            "allowBundled": BUNDLED_SKILLS,
        },
        "plugins": {
            "slots": {
                "memory": "none",
            },
        },
        "agents": {
            "defaults": {
                "workspace": "/home/node/.openclaw/workspace",
                "heartbeat": {
                    "every": "0m",
                },
                "models": allowed_models,
                "sandbox": {
                    "workspaceAccess": "rw",
                    "docker": {
                        "image": values["OPENCLAW_DEFAULT_SANDBOX_IMAGE"],
                        "env": {
                            "HOME": "/workspace/.home",
                            "XDG_CONFIG_HOME": "/workspace/.home/.config",
                            "XDG_CACHE_HOME": "/workspace/.home/.cache",
                            "XDG_STATE_HOME": "/workspace/.home/.local/state",
                            "SSL_CERT_FILE": SANDBOX_CA_BUNDLE_PATH,
                            "REQUESTS_CA_BUNDLE": SANDBOX_CA_BUNDLE_PATH,
                            "NODE_EXTRA_CA_CERTS": SANDBOX_CA_BUNDLE_PATH,
                            "GIT_SSL_CAINFO": SANDBOX_CA_BUNDLE_PATH,
                            "CURL_CA_BUNDLE": SANDBOX_CA_BUNDLE_PATH,
                            "MEMGRAPH_HOST": values["MEMGRAPH_HOST"],
                            "MEMGRAPH_PORT": "7687",
                            "MEMGRAPH_BOLT_URI": (
                                f"bolt://{values['MEMGRAPH_HOST']}:7687" if values["MEMGRAPH_HOST"] else ""
                            ),
                            "QDRANT_URL": qdrant_sandbox_url,
                            "QDRANT_COLLECTION": "openclaw-memory",
                            "QDRANT_API_KEY": "${QDRANT_API_KEY}",
                            "GITHUB_TOKEN": "${GITHUB_TOKEN}",
                            "OPENAI_API_KEY": "${OPENAI_API_KEY}",
                            "ANTHROPIC_API_KEY": "${ANTHROPIC_API_KEY}",
                            "GEMINI_API_KEY": "${GEMINI_API_KEY}",
                        },
                    },
                },
            },
            "list": [
                {
                    "id": "main",
                    "default": True,
                    "name": "OpenClaw Assistant",
                    "workspace": "/home/node/.openclaw/workspace",
                    "heartbeat": {
                        "every": "0m",
                        "includeSystemPromptSection": False,
                    },
                    "model": {
                        "primary": require_string(agent_models["main"]["primary"], "openclaw.agents.main.model"),
                        **(
                            {"fallbacks": require_string_list(agent_models["main"]["fallbacks"], "openclaw.agents.main.fallback_models")}
                            if require_string_list(agent_models["main"]["fallbacks"], "openclaw.agents.main.fallback_models")
                            else {}
                        ),
                    },
                    "subagents": {
                        "allowAgents": ["coder", "architect", "archivist", "auditor"],
                    },
                    "skills": AGENT_SKILLS["main"],
                },
                {
                    "id": "coder",
                    "name": "Coder",
                    "workspace": "/home/node/.openclaw/workspace-coder",
                    "model": {
                        "primary": require_string(agent_models["coder"]["primary"], "openclaw.agents.coder.model"),
                        **(
                            {"fallbacks": require_string_list(agent_models["coder"]["fallbacks"], "openclaw.agents.coder.fallback_models")}
                            if require_string_list(agent_models["coder"]["fallbacks"], "openclaw.agents.coder.fallback_models")
                            else {}
                        ),
                    },
                    "sandbox": {
                        "mode": "all",
                        "workspaceAccess": "rw",
                        "docker": {
                            "image": values["OPENCLAW_CODER_SANDBOX_IMAGE"],
                            "env": {
                                "HOME": "/workspace/.home",
                                "CODEX_HOME": "/workspace/.home/.codex",
                                "XDG_CONFIG_HOME": "/workspace/.home/.config",
                                "XDG_CACHE_HOME": "/workspace/.home/.cache",
                                "XDG_STATE_HOME": "/workspace/.home/.local/state",
                                "SSL_CERT_FILE": SANDBOX_CA_BUNDLE_PATH,
                                "REQUESTS_CA_BUNDLE": SANDBOX_CA_BUNDLE_PATH,
                                "NODE_EXTRA_CA_CERTS": SANDBOX_CA_BUNDLE_PATH,
                                "GIT_SSL_CAINFO": SANDBOX_CA_BUNDLE_PATH,
                                "CURL_CA_BUNDLE": SANDBOX_CA_BUNDLE_PATH,
                                "CODER_GITEA_BASE_URL": gitea_base_url,
                                "CODER_GITEA_TEA_URL": gitea_base_url,
                                "CODER_GITEA_HOST": values["GITEA_HOST"],
                                "CODER_GITEA_USERNAME": values["CODER_GITEA_USERNAME"],
                                "CODER_GITEA_EMAIL": values["CODER_GITEA_EMAIL"],
                                "CODER_GITEA_PASSWORD": "${CODER_GITEA_PASSWORD}",
                                "CODER_GITEA_TOKEN": "${CODER_GITEA_TOKEN}",
                                "CODER_GITOPS_REPO_NAME": values["GITOPS_REPO_NAME"],
                                "CODER_SANDBOX_IMAGES_REPO_NAME": values["SANDBOX_IMAGES_REPO_NAME"],
                                "CODER_GITOPS_REPO_BRANCH": values["GITOPS_REPO_BRANCH"],
                                "CODER_GITOPS_PROJECT": values["GITOPS_PROJECT"],
                                "CODER_GITEA_TEA_LOGIN_NAME": "coder",
                                "CODER_GITEA_TEA_TOKEN_NAME": "openclaw-coder-sandbox",
                                "CODER_REGISTRY_HOST": values["REGISTRY_HOST"],
                                "CODER_REGISTRY_BASE_URL": (
                                    f"https://{values['REGISTRY_HOST']}" if values["REGISTRY_HOST"] else ""
                                ),
                                "CODER_REGISTRY_USERNAME": values["REGISTRY_USERNAME"],
                                "CODER_REGISTRY_PASSWORD": "${CODER_REGISTRY_PASSWORD}",
                                "CODER_REGISTRY_NAMESPACE": values["CODER_GITEA_USERNAME"],
                                "CODEX_DEFAULT_MODEL": values["CODEX_DEFAULT_MODEL"],
                                "CODEX_MODEL": values["CODEX_MODEL"],
                                "DOCKER_HOST": "${DOCKER_HOST}",
                                "OPENAI_API_KEY": "${OPENAI_API_KEY}",
                                "GITHUB_TOKEN": "${GITHUB_TOKEN}",
                            },
                            "setupCommand": "/usr/local/bin/coder-init.sh",
                        },
                    },
                    "skills": AGENT_SKILLS["coder"],
                },
                {
                    "id": "architect",
                    "name": "Architect",
                    "workspace": "/home/node/.openclaw/workspace-architect",
                    "model": {
                        "primary": require_string(agent_models["architect"]["primary"], "openclaw.agents.architect.model"),
                        **(
                            {"fallbacks": require_string_list(agent_models["architect"]["fallbacks"], "openclaw.agents.architect.fallback_models")}
                            if require_string_list(agent_models["architect"]["fallbacks"], "openclaw.agents.architect.fallback_models")
                            else {}
                        ),
                    },
                    "sandbox": {
                        "mode": "non-main",
                        "workspaceAccess": "rw",
                        "docker": {
                            "image": values["OPENCLAW_DEFAULT_SANDBOX_IMAGE"],
                            "workdir": "/workspace",
                            "readOnlyRoot": True,
                            "tmpfs": ["/tmp", "/var/tmp", "/run"],
                            "env": {
                                "HOME": "/workspace/.home",
                                "XDG_CONFIG_HOME": "/workspace/.home/.config",
                                "XDG_CACHE_HOME": "/workspace/.home/.cache",
                                "XDG_STATE_HOME": "/workspace/.home/.local/state",
                                "SSL_CERT_FILE": SANDBOX_CA_BUNDLE_PATH,
                                "REQUESTS_CA_BUNDLE": SANDBOX_CA_BUNDLE_PATH,
                                "NODE_EXTRA_CA_CERTS": SANDBOX_CA_BUNDLE_PATH,
                                "GIT_SSL_CAINFO": SANDBOX_CA_BUNDLE_PATH,
                                "CURL_CA_BUNDLE": SANDBOX_CA_BUNDLE_PATH,
                                "MEMGRAPH_HOST": values["MEMGRAPH_HOST"],
                                "MEMGRAPH_PORT": "7687",
                                "MEMGRAPH_BOLT_URI": (
                                    f"bolt://{values['MEMGRAPH_HOST']}:7687" if values["MEMGRAPH_HOST"] else ""
                                ),
                                "QDRANT_URL": f"https://{values['QDRANT_HOST']}" if values["QDRANT_HOST"] else "",
                                "QDRANT_COLLECTION": "openclaw-memory",
                                "QDRANT_API_KEY": "${QDRANT_API_KEY}",
                                "GITHUB_TOKEN": "${GITHUB_TOKEN}",
                                "OPENAI_API_KEY": "${OPENAI_API_KEY}",
                                "ANTHROPIC_API_KEY": "${ANTHROPIC_API_KEY}",
                                "GEMINI_API_KEY": "${GEMINI_API_KEY}",
                                "REVIEWER_GITEA_BASE_URL": gitea_base_url,
                                "REVIEWER_GITEA_TEA_URL": gitea_base_url,
                                "REVIEWER_GITEA_HOST": values["GITEA_HOST"],
                                "REVIEWER_GITEA_USERNAME": values["REVIEWER_GITEA_USERNAME"],
                                "REVIEWER_GITEA_EMAIL": values["REVIEWER_GITEA_EMAIL"],
                                "REVIEWER_GITEA_PASSWORD": "${REVIEWER_GITEA_PASSWORD}",
                                "REVIEWER_GITEA_TOKEN": "${REVIEWER_GITEA_TOKEN}",
                                "REVIEWER_GITEA_TEA_LOGIN_NAME": "reviewer",
                                "REVIEWER_GITEA_TEA_TOKEN_NAME": "openclaw-reviewer",
                            },
                            "user": "1000:1000",
                            "capDrop": ["ALL"],
                            "pidsLimit": 256,
                            "memory": "1g",
                            "memorySwap": "2g",
                            "cpus": 1,
                            "network": "bridge",
                            "setupCommand": "/usr/local/bin/reviewer-gitea-init.sh",
                        },
                    },
                    "skills": AGENT_SKILLS["architect"],
                    "tools": {"deny": AGENT_TOOL_DENY["architect"]},
                },
                {
                    "id": "archivist",
                    "name": "Archivist",
                    "workspace": "/home/node/.openclaw/workspace-archivist",
                    "model": {
                        "primary": require_string(agent_models["archivist"]["primary"], "openclaw.agents.archivist.model"),
                        **(
                            {"fallbacks": require_string_list(agent_models["archivist"]["fallbacks"], "openclaw.agents.archivist.fallback_models")}
                            if require_string_list(agent_models["archivist"]["fallbacks"], "openclaw.agents.archivist.fallback_models")
                            else {}
                        ),
                    },
                    "sandbox": {"mode": "non-main"},
                    "skills": AGENT_SKILLS["archivist"],
                    "tools": {"deny": AGENT_TOOL_DENY["archivist"]},
                },
                {
                    "id": "watchdog",
                    "name": "Watchdog",
                    "workspace": "/home/node/.openclaw/workspace-watchdog",
                    "heartbeat": {
                        "every": "30m",
                    },
                    "model": {
                        "primary": require_string(agent_models["watchdog"]["primary"], "openclaw.agents.watchdog.model"),
                        **(
                            {"fallbacks": require_string_list(agent_models["watchdog"]["fallbacks"], "openclaw.agents.watchdog.fallback_models")}
                            if require_string_list(agent_models["watchdog"]["fallbacks"], "openclaw.agents.watchdog.fallback_models")
                            else {}
                        ),
                    },
                    "sandbox": {
                        "mode": "off",
                    },
                    "skills": AGENT_SKILLS["watchdog"],
                    "tools": {"deny": AGENT_TOOL_DENY["watchdog"]},
                },
                {
                    "id": "auditor",
                    "name": "Auditor",
                    "workspace": "/home/node/.openclaw/workspace-auditor",
                    "model": {
                        "primary": require_string(agent_models["auditor"]["primary"], "openclaw.agents.auditor.model"),
                        **(
                            {"fallbacks": require_string_list(agent_models["auditor"]["fallbacks"], "openclaw.agents.auditor.fallback_models")}
                            if require_string_list(agent_models["auditor"]["fallbacks"], "openclaw.agents.auditor.fallback_models")
                            else {}
                        ),
                    },
                    "sandbox": {
                        "mode": "off",
                    },
                    "skills": AGENT_SKILLS["auditor"],
                    "tools": {"deny": AGENT_TOOL_DENY["auditor"]},
                },
            ],
        },
        "tools": {
            "sessions": {
                "visibility": "all",
            },
            "agentToAgent": {
                "enabled": True,
                "allow": ["main", "coder", "architect", "archivist", "watchdog", "auditor"],
            }
        },
    }
    openclaw["openclaw"]["cron"] = {
        "enabled": True,
        "store": "~/.openclaw/cron/jobs.json",
        "maxConcurrentRuns": 1,
        "sessionRetention": "24h",
        "runLog": {
            "maxBytes": "2mb",
            "keepLines": 2000,
        },
    }
    openclaw["env"] = [
        {"name": "XDG_CONFIG_HOME", "value": "/home/node/.openclaw/.config"},
        {"name": "XDG_CACHE_HOME", "value": "/home/node/.openclaw/.cache"},
        {"name": "XDG_STATE_HOME", "value": "/home/node/.openclaw/.local/state"},
        {"name": "GIT_CONFIG_GLOBAL", "value": "/home/node/.openclaw/.config/git/config"},
        {"name": "MEMGRAPH_HOST", "value": '{{ printf "%s-memgraph" .Release.Name | trunc 63 | trimSuffix "-" }}'},
        {"name": "MEMGRAPH_PORT", "value": "7687"},
        {
            "name": "MEMGRAPH_BOLT_URI",
            "value": 'bolt://{{ printf "%s-memgraph" .Release.Name | trunc 63 | trimSuffix "-" }}:7687',
        },
        {"name": "CODER_GITEA_BASE_URL", "value": gitea_base_url},
        {"name": "CODER_GITEA_BOOTSTRAP_URL", "value": internal_gitea_service_base_url},
        {"name": "CODER_GITEA_TEA_URL", "value": internal_gitea_service_base_url},
        {"name": "CODER_GITEA_HOST", "value": values["GITEA_HOST"]},
        {"name": "CODER_GITEA_USERNAME", "value": values["CODER_GITEA_USERNAME"]},
        {"name": "CODER_GITEA_EMAIL", "value": values["CODER_GITEA_EMAIL"]},
        {"name": "CODER_GITEA_TEA_LOGIN_NAME", "value": "coder"},
        {"name": "CODER_GITEA_TEA_TOKEN_NAME", "value": "openclaw-coder-sandbox"},
        {"name": "CODER_REGISTRY_HOST", "value": values["REGISTRY_HOST"]},
        {"name": "CODER_REGISTRY_USERNAME", "value": values["REGISTRY_USERNAME"]},
        {
            "name": "CODER_REGISTRY_BASE_URL",
            "value": (f"https://{values['REGISTRY_HOST']}" if values["REGISTRY_HOST"] else ""),
        },
        {"name": "REVIEWER_GITEA_BASE_URL", "value": internal_gitea_service_base_url},
        {"name": "REVIEWER_GITEA_BOOTSTRAP_URL", "value": internal_gitea_service_base_url},
        {"name": "REVIEWER_GITEA_TEA_URL", "value": internal_gitea_service_base_url},
        {"name": "REVIEWER_GITEA_HOST", "value": internal_gitea_service_host},
        {"name": "REVIEWER_GITEA_USERNAME", "value": values["REVIEWER_GITEA_USERNAME"]},
        {"name": "REVIEWER_GITEA_EMAIL", "value": values["REVIEWER_GITEA_EMAIL"]},
        {"name": "REVIEWER_GITEA_TEA_LOGIN_NAME", "value": "reviewer"},
        {"name": "REVIEWER_GITEA_TEA_TOKEN_NAME", "value": "openclaw-reviewer"},
    ]
    openclaw.setdefault("openclaw", {}).setdefault("commands", {})["mcp"] = True
    mcp_servers: dict[str, object] = {}
    if values["NEXTCLOUD_MCP_HOST"]:
        mcp_servers["nextcloud"] = {
            "command": "node",
            "args": [
                SHARED_MCP_BRIDGE_PATH,
                "--url",
                "${OPENCLAW_NEXTCLOUD_MCP_INTERNAL_URL}",
                "--url",
                "${OPENCLAW_NEXTCLOUD_MCP_EXTERNAL_URL}",
                "--header",
                "Authorization=${OPENCLAW_NEXTCLOUD_MCP_AUTH_HEADER}",
            ],
        }
    if values["QDRANT_MCP_HOST"]:
        mcp_servers["qdrant"] = {
            "command": "node",
            "args": [
                SHARED_MCP_BRIDGE_PATH,
                "--url",
                "${OPENCLAW_QDRANT_MCP_INTERNAL_URL}",
                "--url",
                "${OPENCLAW_QDRANT_MCP_EXTERNAL_URL}",
            ],
        }
    if mcp_servers:
        openclaw["openclaw"]["mcp"] = {"servers": mcp_servers}
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
            "actions": {
                "enabled": values["GITEA_ACTIONS_ENABLED"] == "true",
                "runner": {
                    "vmName": values["GITEA_ACTIONS_RUNNER_VM_NAME"],
                    "hostAlias": values["GITEA_ACTIONS_RUNNER_HOST_ALIAS"],
                    "sshPort": int(values["GITEA_ACTIONS_RUNNER_SSH_PORT"]),
                    "labels": values["GITEA_ACTIONS_RUNNER_LABEL_NAMES"].split(",")
                    if values["GITEA_ACTIONS_RUNNER_LABEL_NAMES"]
                    else [],
                    "jobImage": values["GITEA_ACTIONS_JOB_IMAGE"],
                },
            },
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
        "registry": {
            "auth": {
                "existingSecret": "registry-auth-secret",
            },
            "ingress": (
                {
                    "hosts": [
                        {
                            "host": values["REGISTRY_HOST"],
                            "paths": [{"path": "/", "pathType": "Prefix"}],
                        }
                    ],
                    "tls": [
                        {
                            "secretName": "registry-tls",
                            "hosts": [values["REGISTRY_HOST"]],
                        }
                    ],
                }
                if values["REGISTRY_HOST"]
                else {}
            ),
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
                host
                for host in (
                    values["NEXTCLOUD_HOST"],
                    values["NEXTCLOUD_PUBLIC_HOST"],
                    "platform-stack-nextcloud",
                    "platform-stack-nextcloud.ai-homebase.svc",
                    "platform-stack-nextcloud.ai-homebase.svc.cluster.local",
                )
                if host
            ],
            "bootstrapUsers": [
                {
                    "username": NEXTCLOUD_MCP_USERNAME,
                    "displayName": "OpenClaw",
                    "passwordSecret": {
                        "name": "openclaw-nextcloud-mcp-secrets",
                        "key": "NEXTCLOUD_PASSWORD",
                    },
                }
            ],
            "bootstrapProjectContent": nextcloud_project_bootstrap_values(),
        },
        "nextcloudMcp": {
            "ingress": (
                {
                    "hosts": [
                        {
                            "host": values["NEXTCLOUD_MCP_HOST"],
                            "paths": [{"path": "/", "pathType": "Prefix"}],
                        }
                    ],
                    "tls": [
                        {
                            "secretName": "nextcloud-mcp-tls",
                            "hosts": [values["NEXTCLOUD_MCP_HOST"]],
                        }
                    ],
                }
                if values["NEXTCLOUD_MCP_HOST"]
                else {}
            ),
        },
        "qdrant": {
            "ingress": (
                {
                    "hosts": [
                        {
                            "host": values["QDRANT_HOST"],
                            "paths": [{"path": "/", "pathType": "Prefix"}],
                        }
                    ],
                    "tls": [
                        {
                            "secretName": "qdrant-tls",
                            "hosts": [values["QDRANT_HOST"]],
                        }
                    ],
                }
                if values["QDRANT_HOST"]
                else {}
            ),
        },
        "qdrantMcp": {
            "ingress": (
                {
                    "hosts": [
                        {
                            "host": values["QDRANT_MCP_HOST"],
                            "paths": [{"path": "/", "pathType": "Prefix"}],
                        }
                    ],
                    "tls": [
                        {
                            "secretName": "qdrant-mcp-tls",
                            "hosts": [values["QDRANT_MCP_HOST"]],
                        }
                    ],
                }
                if values["QDRANT_MCP_HOST"]
                else {}
            ),
        },
        "memgraph": {
            "ingress": (
                {
                    "hosts": [
                        {
                            "host": values["MEMGRAPH_HOST"],
                            "paths": [{"path": "/", "pathType": "Prefix"}],
                        }
                    ],
                    "tls": [
                        {
                            "secretName": "memgraph-tls",
                            "hosts": [values["MEMGRAPH_HOST"]],
                        }
                    ],
                }
                if values["MEMGRAPH_HOST"]
                else {}
            ),
        },
        "memgraphLab": {
            "ingress": (
                {
                    "hosts": [
                        {
                            "host": values["MEMGRAPH_LAB_HOST"],
                            "paths": [{"path": "/", "pathType": "Prefix"}],
                        }
                    ],
                    "tls": [
                        {
                            "secretName": "memgraph-lab-tls",
                            "hosts": [values["MEMGRAPH_LAB_HOST"]],
                        }
                    ],
                }
                if values["MEMGRAPH_LAB_HOST"]
                else {}
            ),
            "memgraph": {
                "host": "platform-stack-memgraph",
                "port": 7687,
            },
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
    workspace_bootstrap["giteaAdminUsername"] = values["GITEA_ADMIN_USERNAME"]
    rendered["openclaw"]["workspaceBootstrap"] = workspace_bootstrap
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
