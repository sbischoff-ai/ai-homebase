#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import json
import shlex
import sys
import textwrap
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
DEFAULT_CODER_MODEL = "openai/gpt-5.4"
DEFAULT_ARCHITECT_MODEL = "anthropic/claude-opus-4-6"
SHARED_MCP_BRIDGE_PATH = "/opt/openclaw-runtime/mcp/mcp-http-bridge.mjs"
NEXTCLOUD_MCP_USERNAME = "openclaw"
DEFAULT_CODER_SANDBOX_IMAGE = "openclaw-sandbox-coder:bookworm-slim"
DEFAULT_CODER_GITEA_USERNAME = "coder"

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


def nested_nonempty_string(data: dict[str, object], path: tuple[str, ...], default: str = "") -> str:
    value = nested_string(data, path, default)
    if value == "":
        return default
    return value


def normalize_markdown(text: str) -> str:
    return textwrap.dedent(text).strip() + "\n"


def workspace_bootstrap_values(
    user_nextcloud_username: str,
    user_gitea_username: str,
    coder_gitea_username: str,
    gitea_host: str,
) -> dict[str, object]:
    gitea_scheme = "http" if gitea_host.endswith(".localtest.me") else "https"
    gitea_base_url = f"{gitea_scheme}://{gitea_host}"
    return {
        "enabled": True,
        "agents": {
            "main": {
                "workspace": "/home/node/.openclaw/workspace",
                "files": {
                    "AGENTS.md": normalize_markdown(
                        f"""
                        # Main

                        You are the user's primary interface to this OpenClaw setup.

                        Responsibilities:
                        - Own coordination, delegation, and decision flow.
                        - Break requests into clear subproblems and route them to the right specialist.
                        - Integrate specialist results and present them back to the user.
                        - Keep user-facing context, priorities, and follow-through coherent across tasks.

                        Boundaries:
                        - Do not do deep planning, system design, or long-horizon creative exploration yourself when architect should handle it.
                        - Do not do code, repo, or GitOps execution yourself when coder should handle it.

                        Delegation:
                        - Delegate planning, design, specification, tradeoff analysis, and heavy creative ideation to architect.
                        - Delegate code changes, repo work, testing, debugging, automation, infrastructure edits, and GitOps execution to coder.
                        - Architect and coder are specialists. You remain the orchestrator and the user's point of contact.
                        - Use `sessions_send` to communicate with the specialists' main sessions at `agent:coder:main` and `agent:architect:main`.
                        - You may also use `sessions_spawn` to spawn coder or architect as sub-agents when that is the better interaction pattern for the work.
                        """
                    ),
                    "SOUL.md": normalize_markdown(
                        """
                        Operate as a calm orchestrator and personal assistant.

                        Prefer decomposition, delegation, synthesis, and follow-through over doing specialist work directly.
                        """
                    ),
                    "TOOLS.md": normalize_markdown(
                        f"""
                        You have a dedicated Nextcloud account available through your visible Nextcloud MCP tools.

                        Use it to:
                        - store notes that may be useful to share with the user;
                        - keep durable working notes when the information should outlive the current chat;
                        - organize user-facing material so it can be found again later.

                        Nextcloud account details:
                        - Agent account username: `{NEXTCLOUD_MCP_USERNAME}`
                        - User's Nextcloud username: `{user_nextcloud_username}`

                        Calendar instruction:
                        - Ask the user to create a calendar and share it with `{NEXTCLOUD_MCP_USERNAME}` so you can track shared planning items there.

                        Specialist routing:
                        - Use architect for planning, design, specifications, and heavy creative work.
                        - Use coder for all code, repo, and GitOps execution.
                        - Contact architect and coder through `sessions_send` to their main sessions at `agent:architect:main` and `agent:coder:main`.
                        - You may also use `sessions_spawn` to spawn coder or architect as sub-agents when you want a task to run as a sub-agent instead of as a standing specialist session.
                        - Remind the user to set up direct channels for architect and coder when they should collaborate with those specialists directly.
                        """
                    ),
                    "USER.md": normalize_markdown(
                        f"""
                        # User Notes

                        The user's Nextcloud username is `{user_nextcloud_username}`.

                        Confirm during bootstrap how the user wants to be addressed, what they want help with, and whether this username is still correct.
                        """
                    ),
                    "IDENTITY.md": normalize_markdown(
                        """
                        # Identity

                        Initial role: main orchestrator / personal assistant for this homebase stack.
                        """
                    ),
                    "HEARTBEAT.md": normalize_markdown(
                        """
                        Check whether there are durable notes or shared planning items that should be written to Nextcloud instead of living only in transient chat history.
                        """
                    ),
                    "MEMORY.md": normalize_markdown(
                        """
                        Keep durable user-facing notes and decisions tidy. Prefer Nextcloud for information the user may need to access or share later.
                        """
                    ),
                    "BOOTSTRAP.md": normalize_markdown(
                        f"""
                        Start a normal first-use bootstrap conversation with the user.

                        During bootstrap:
                        - ask what the user wants to call you;
                        - ask what personality or interaction style the user wants you to exhibit;
                        - learn how the user wants to work with you;
                        - confirm how they want to be addressed;
                        - confirm that their Nextcloud username is `{user_nextcloud_username}`;
                        - explain the stack at a high level: you orchestrate, architect plans, coder executes, and the stack includes shared Nextcloud, Gitea, GitOps, and specialist agents;
                        - help the user set up a direct channel for you;
                        - use `sessions_send` to start `agent:coder:main` and `agent:architect:main` right away so those specialist main sessions are live from the start;
                        - explain that you can use the dedicated Nextcloud account `{NEXTCLOUD_MCP_USERNAME}` for shared notes;
                        - ask the user to create a calendar and share it with `{NEXTCLOUD_MCP_USERNAME}`;
                        - remind the user to set up direct channels for architect and coder if they want to workshop plans or coordinate implementation with them directly;
                        - capture that coding belongs with coder and planning or design belongs with architect.

                        Update the workspace files as needed and remove this file when bootstrap is complete.
                        """
                    ),
                },
            },
            "coder": {
                "workspace": "/home/node/.openclaw/workspace-coder",
                "files": {
                    "AGENTS.md": normalize_markdown(
                        """
                        # Coder

                        You own the programming domain for this OpenClaw setup.

                        Responsibilities:
                        - Own code changes, repository work, tests, debugging, refactors, automation, and GitOps execution.
                        - Take holistic ownership of implementation work rather than treating requests as isolated code edits.
                        - Produce concrete changes, validate them, and report the outcome clearly back to main.
                        - Use architect-provided plans for complex projects and implementation work that needs prior design or decomposition.

                        Boundaries:
                        - Main owns coordination, user interaction, and final synthesis.
                        - Architect owns broad planning, design, and long-horizon reasoning.
                        - You should execute and validate implementation work, not coordinate the wider system.
                        - Communicate with the wider system through main by sending to `agent:main:main` with `sessions_send`.
                        - Keep architect-to-coder coordination routed through main.
                        """
                    ),
                    "SOUL.md": normalize_markdown(
                        """
                        Operate as an implementer. Be concrete, decisive, and validation-focused.
                        """
                    ),
                    "TOOLS.md": normalize_markdown(
                        f"""
                        Use your visible coding and runtime tools to inspect repositories, make changes, run validations, and prepare commits when appropriate.

                        Work inside the sandbox by default and treat mutation, testing, and GitOps updates as part of your core function.

                        Local skills:
                        - Use `gitea-tea` for repository creation, collaborator management, pull requests, and other Gitea workflows.
                        - Use `gitops-homebase` when you work in the GitOps repository or touch Helm and cluster-definition changes.

                        Runtime environment:
                        - You run inside a dedicated remote Docker sandbox image for coding work.
                        - Common tools available include `bash`, `curl`, `jq`, `yq`, `rg`, `make`, `git`, `tea`, `helm`, `node`, `npm`, `python3`, `pip`, `uv`, `cargo`, `rustc`, `go`, and `ssh`.
                        - Shared MCP tools remain available in the sandbox, including the Nextcloud tools.
                        - The Gitea ingress hostname `{gitea_host}` should resolve from your sandbox runtime.

                        Gitea guidance:
                        - Your Gitea username is `{coder_gitea_username}` on `{gitea_base_url}`.
                        - Use git and tea with that identity for repository work.
                        - The GitOps repository is one of your execution targets. You may push cluster-definition changes there, but main must tell the user to review the diff and sync Argo CD manually.
                        - When you create a new repository for a project, invite the user `{user_gitea_username}` as a collaborator.
                        - When you work on repositories owned by the user or shared with the user, create pull requests and tell main that the user needs to review and merge them.
                        - If direct discussion with the user would materially improve implementation, remind main that you need a dedicated user channel.

                        Nextcloud guidance:
                        - Main owns the shared calendar, user-facing scheduling, and general coordination state.
                        - Use Nextcloud Notes only when they genuinely help implementation, handoff, or durable engineering context.
                        - Tag your shared notes with `#coder` and a project-specific tag when possible.
                        - If you create or update durable material, remember the exact note title, folder, table, file path, or share location so you can find it later.
                        - Tell main where you stored anything user-relevant.

                        Agent communication:
                        - Use `sessions_send` to communicate with other agents through their main sessions.
                        - Your normal coordination target is `agent:main:main`.
                        - Do not use `sessions_spawn`; main owns sub-agent spawning.
                        """
                    ),
                    "USER.md": normalize_markdown(
                        f"""
                        The user works through main. Keep handoff notes concise, factual, and ready for main to present or integrate.

                        The user's Gitea username is `{user_gitea_username}`.
                        Invite that user to repositories you create for them. If they want to work with you directly, main should help them set up a dedicated channel.
                        """
                    ),
                    "IDENTITY.md": normalize_markdown(
                        """
                        # Identity

                        Specialist role: coder / executor / implementer.
                        """
                    ),
                    "HEARTBEAT.md": normalize_markdown(
                        """
                        Before finishing, check whether the implementation is validated enough for main to rely on it.
                        """
                    ),
                    "MEMORY.md": normalize_markdown(
                        """
                        Keep durable implementation context focused on codebase conventions, execution constraints, and known repo workflows.
                        """
                    ),
                    "skills/gitea-tea/SKILL.md": normalize_markdown(
                        """
                        ---
                        name: gitea-tea
                        description: Operate against the in-cluster Gitea service with git and tea for repos, collaborators, issues, and pull requests.
                        ---

                        Use this skill when you need to work with Gitea as the coding/execution specialist.

                        Conventions:
                        - Prefer the in-cluster Gitea instance for project repos and collaboration.
                        - Use your configured coder identity for all git and tea operations.
                        - Invite the user to repositories you create for them.
                        - For shared or user-owned repositories, prefer branches and pull requests over direct pushes.
                        - Tell main when user review or merge action is required.

                        Typical work:
                        - create repositories for new implementation projects;
                        - clone, branch, commit, and push implementation work;
                        - open pull requests;
                        - add collaborators;
                        - inspect issues, pull requests, and repo metadata.
                        """
                    ),
                    "skills/gitops-homebase/SKILL.md": normalize_markdown(
                        """
                        ---
                        name: gitops-homebase
                        description: Execute GitOps changes safely in the ai-homebase repos and hand off review/sync to the user through main.
                        ---

                        Use this skill when implementation work affects cluster definitions, Helm values, or GitOps-managed manifests.

                        Rules:
                        - Treat the GitOps repository as a deployment-definition repo, not a place for speculative planning.
                        - Validate changes with the repo's documented lint and render commands before handoff.
                        - Push GitOps changes when appropriate, but tell main that the user must review the diff and manually sync Argo CD.
                        - If the work requires new planning, missing requirements, or broad design decisions, hand back to main so architect can refine the plan first.

                        Validation commands for this repo:
                        - `./scripts/lint.sh --values-file charts/platform-stack/values.yaml`
                        - `./scripts/lint.sh --values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3d.yaml`
                        - `./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml > /tmp/platform-stack.yaml`
                        """
                    ),
                },
            },
            "architect": {
                "workspace": "/home/node/.openclaw/workspace-architect",
                "files": {
                    "AGENTS.md": normalize_markdown(
                        """
                        # Architect

                        You are the planning and design specialist for this OpenClaw setup.

                        Responsibilities:
                        - Turn goals into plans, designs, specifications, tradeoff analyses, and structured execution guidance.
                        - Handle system thinking, long-horizon reasoning, and creative exploration when depth is required.
                        - Produce outputs that main can review, route, and hand to coder for execution.
                        - Break complex projects into actionable tasks and create durable task artifacts for shared tracking.

                        Boundaries:
                        - Do not modify repositories, execute code changes, or manage GitOps work.
                        - Do not replace main as the coordinator or user-facing decision owner.
                        - Architect-to-coder flow goes through main.
                        - Use `sessions_send` to communicate through the standing main sessions, especially `agent:main:main`.
                        - Do not use `sessions_spawn`; main owns sub-agent spawning.
                        """
                    ),
                    "SOUL.md": normalize_markdown(
                        """
                        Operate as a planner and designer. Aim for clarity, structure, tradeoff-awareness, and implementation-ready output.
                        """
                    ),
                    "TOOLS.md": normalize_markdown(
                        """
                        Use your visible Nextcloud tools to keep durable planning output when that helps the user.

                        Good uses:
                        - design documents and concept notes;
                        - structured plans and specifications;
                        - todo-oriented planning output for shared tracking.

                        Shared-account guidance:
                        - Tag your shared notes with `#architect` and a project-specific tag when possible.
                        - Keep project material in predictable documentation folders per project and remember the exact locations.
                        - Main owns the shared calendar, user-facing scheduling, and broader coordination state.
                        - Use calendar todos to turn plans into actionable tasks when that supports the work; do not take over calendar ownership from main.
                        - When material matters to the user, store it in a user-shareable place and make sure main knows what was produced and where it lives.
                        - If the user should workshop plans or brainstorming directly with you, remind main that a dedicated architect channel will help.

                        Agent communication:
                        - Use `sessions_send` to communicate with the other agents' main sessions.
                        - Your normal coordination target is `agent:main:main`.
                        """
                    ),
                    "USER.md": normalize_markdown(
                        f"""
                        Main is the user's interface. The user's Nextcloud username is `{user_nextcloud_username}`.

                        If your output should be visible or shareable for the user, structure it so main can hand it back cleanly.
                        """
                    ),
                    "IDENTITY.md": normalize_markdown(
                        """
                        # Identity

                        Specialist role: architect / planner / designer.
                        """
                    ),
                    "HEARTBEAT.md": normalize_markdown(
                        """
                        Before finishing, check whether the plan is concrete enough for main to route and coder to implement.
                        """
                    ),
                    "MEMORY.md": normalize_markdown(
                        """
                        Keep durable planning patterns, architecture decisions, and reusable design context here when they will matter again.
                        """
                    ),
                },
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


def resolved_values(data: dict[str, object]) -> dict[str, str]:
    providers = provider_values(data)
    main_model = nested_nonempty_string(data, ("openclaw", "agents", "main", "model"), DEFAULT_MAIN_MODEL)
    coder_model = nested_nonempty_string(data, ("openclaw", "agents", "coder", "model"), DEFAULT_CODER_MODEL)
    architect_model = nested_nonempty_string(
        data, ("openclaw", "agents", "architect", "model"), DEFAULT_ARCHITECT_MODEL
    )

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
    for model_key, model_value in (
        ("openclaw.agents.main.model", main_model),
        ("openclaw.agents.coder.model", coder_model),
        ("openclaw.agents.architect.model", architect_model),
    ):
        if "/" not in model_value:
            raise SystemExit(f"{model_key} must use the OpenClaw provider/model form, for example openai/gpt-5.4.")
        provider_env_var = provider_env_var_for_model(model_value)
        if not providers.get(provider_env_var, ""):
            raise SystemExit(
                f"{model_key}={model_value!r} requires {provider_env_var} in [providers]."
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
        "CODER_GITEA_USERNAME": coder_gitea_username,
        "CODER_GITEA_EMAIL": coder_gitea_email,
        "CODER_GITEA_PASSWORD": coder_gitea_password,
        "OPENCLAW_CODER_SANDBOX_IMAGE": DEFAULT_CODER_SANDBOX_IMAGE,
        "OPENCLAW_MAIN_MODEL": main_model,
        "OPENCLAW_CODER_MODEL": coder_model,
        "OPENCLAW_ARCHITECT_MODEL": architect_model,
    }
    gitops_table = data.get("gitops")
    if isinstance(gitops_table, dict) and "repo_private" in gitops_table:
        if not isinstance(gitops_table["repo_private"], bool):
            raise SystemExit("gitops.repo_private must be a boolean")
        values["GITOPS_REPO_PRIVATE"] = "true" if gitops_table["repo_private"] else "false"
    if not values["CODER_GITEA_EMAIL"]:
        values["CODER_GITEA_EMAIL"] = f"{values['CODER_GITEA_USERNAME']}@example.invalid"
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
    workspace_bootstrap = workspace_bootstrap_values(
        values["NEXTCLOUD_ADMIN_USER"],
        values["GITEA_USER_USERNAME"],
        values["CODER_GITEA_USERNAME"],
        values["GITEA_HOST"],
    )
    allowed_models = {
        model_id: {"alias": alias}
        for model_id, alias in (
            (values["OPENCLAW_MAIN_MODEL"], "Main"),
            (values["OPENCLAW_CODER_MODEL"], "Coder"),
            (values["OPENCLAW_ARCHITECT_MODEL"], "Architect"),
        )
    }
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
        "nextcloudMcp": values["NEXTCLOUD_MCP_HOST"],
        "gitea": values["GITEA_HOST"],
        "argocd": values["ARGOCD_HOST"],
        "vaultwarden": values["VAULTWARDEN_HOST"],
        "paperlessNgx": values["PAPERLESS_HOST"],
    }
    full_mail_from = f"{values['MAIL_FROM_LOCALPART']}@{values['MAIL_DOMAIN']}"
    gitea_scheme = "http" if values["GITEA_HOST"].endswith(".localtest.me") else "https"
    gitea_base_url = f"{gitea_scheme}://{values['GITEA_HOST']}"
    coder_setup_command = textwrap.dedent(
        f"""
        set -eu
        mkdir -p "${{HOME}}/.config/tea" "${{HOME}}/.cache" "${{HOME}}/.local/state"
        git config --global user.name {shlex.quote(values["CODER_GITEA_USERNAME"])}
        git config --global user.email {shlex.quote(values["CODER_GITEA_EMAIL"])}
        cat > "${{HOME}}/.netrc" <<'EOF'
        machine {values["GITEA_HOST"]}
          login {values["CODER_GITEA_USERNAME"]}
          password {values["CODER_GITEA_PASSWORD"]}
        EOF
        chmod 0600 "${{HOME}}/.netrc"
        existing_token_ids="$(curl -fsS -u {shlex.quote(values["CODER_GITEA_USERNAME"] + ":" + values["CODER_GITEA_PASSWORD"])} {shlex.quote(gitea_base_url + f"/api/v1/users/{values['CODER_GITEA_USERNAME']}/tokens")} | jq -r '.[] | select(.name == "openclaw-coder-sandbox") | .id' || true)"
        if [ -n "${{existing_token_ids}}" ]; then
          for token_id in $existing_token_ids; do
            curl -fsS -X DELETE -u {shlex.quote(values["CODER_GITEA_USERNAME"] + ":" + values["CODER_GITEA_PASSWORD"])} {shlex.quote(gitea_base_url + f"/api/v1/users/{values['CODER_GITEA_USERNAME']}/tokens/")}${{token_id}} >/dev/null || true
          done
        fi
        token="$(curl -fsS -u {shlex.quote(values["CODER_GITEA_USERNAME"] + ":" + values["CODER_GITEA_PASSWORD"])} -H 'Content-Type: application/json' -d '{{"name":"openclaw-coder-sandbox","scopes":["all"]}}' {shlex.quote(gitea_base_url + f"/api/v1/users/{values['CODER_GITEA_USERNAME']}/tokens")} 2>/dev/null | jq -r '.sha1 // empty' || true)"
        if [ -n "${{token}}" ]; then
          tea login add --name coder --url {shlex.quote(gitea_base_url)} --token "${{token}}" >/dev/null 2>&1 || true
        fi
        """
    ).strip()
    openclaw["openclaw"] = {
        "agents": {
            "defaults": {
                "workspace": "/home/node/.openclaw/workspace",
                "models": allowed_models,
            },
            "list": [
                {
                    "id": "main",
                    "default": True,
                    "name": "OpenClaw Assistant",
                    "workspace": "/home/node/.openclaw/workspace",
                    "model": {
                        "primary": values["OPENCLAW_MAIN_MODEL"],
                    },
                    "subagents": {
                        "allowAgents": ["coder", "architect"],
                    },
                },
                {
                    "id": "coder",
                    "name": "Coder",
                    "workspace": "/home/node/.openclaw/workspace-coder",
                    "model": {
                        "primary": values["OPENCLAW_CODER_MODEL"],
                    },
                    "sandbox": {
                        "mode": "all",
                        "docker": {
                            "image": values["OPENCLAW_CODER_SANDBOX_IMAGE"],
                            "env": {
                                "CODER_GITEA_BASE_URL": gitea_base_url,
                                "CODER_GITEA_HOST": values["GITEA_HOST"],
                                "CODER_GITEA_USERNAME": values["CODER_GITEA_USERNAME"],
                                "CODER_GITEA_EMAIL": values["CODER_GITEA_EMAIL"],
                                "CODER_GITEA_PASSWORD": values["CODER_GITEA_PASSWORD"],
                                "CODER_GITOPS_REPO_NAME": values["GITOPS_REPO_NAME"],
                                "CODER_GITOPS_REPO_BRANCH": values["GITOPS_REPO_BRANCH"],
                                "CODER_GITOPS_PROJECT": values["GITOPS_PROJECT"],
                                "CODER_GITEA_TEA_LOGIN_NAME": "coder",
                                "CODER_GITEA_TEA_TOKEN_NAME": "openclaw-coder-sandbox",
                            },
                            "setupCommand": coder_setup_command,
                        },
                    },
                },
                {
                    "id": "architect",
                    "name": "Architect",
                    "workspace": "/home/node/.openclaw/workspace-architect",
                    "model": {
                        "primary": values["OPENCLAW_ARCHITECT_MODEL"],
                    },
                },
            ],
        },
        "tools": {
            "sessions": {
                "visibility": "all",
            },
            "agentToAgent": {
                "enabled": True,
                "allow": ["main", "coder", "architect"],
            }
        },
    }
    openclaw.setdefault("openclaw", {}).setdefault("commands", {})["mcp"] = True
    if values["NEXTCLOUD_MCP_HOST"]:
        openclaw["openclaw"]["mcp"] = {
            "servers": {
                "nextcloud": {
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
