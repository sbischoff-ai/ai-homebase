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
DEFAULT_CODER_MODEL = "anthropic/claude-sonnet-4-5"
DEFAULT_ARCHITECT_MODEL = "anthropic/claude-opus-4-6"
DEFAULT_WATCHDOG_MODEL = "anthropic/claude-haiku-4-5"
SHARED_MCP_BRIDGE_PATH = "/opt/openclaw-runtime/mcp/mcp-http-bridge.mjs"
NEXTCLOUD_MCP_USERNAME = "openclaw"
DEFAULT_CODER_SANDBOX_IMAGE = "openclaw-sandbox-coder:bookworm-slim"
DEFAULT_CODER_GITEA_USERNAME = "coder"
DEFAULT_REGISTRY_USERNAME = "coder"
BUNDLED_SKILLS = [
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


def nested_nonempty_string(data: dict[str, object], path: tuple[str, ...], default: str = "") -> str:
    value = nested_string(data, path, default)
    if value == "":
        return default
    return value


def normalize_markdown(text: str) -> str:
    return textwrap.dedent(text).strip() + "\n"


def seeded_nextcloud_project_content() -> list[dict[str, object]]:
    return [
        {
            "slug": "ai-homebase",
            "ownerUsername": NEXTCLOUD_MCP_USERNAME,
            "projectsFiles": [
                {
                    "path": "overview.md",
                    "content": normalize_markdown(
                        """
                        # ai-homebase

                        This project documents the running AI homebase cluster from the perspective of the agents operating inside it.

                        Purpose:
                        - explain what this cluster is for;
                        - describe how the agents should work within it;
                        - capture the durable operating model for evolving the stack over time.

                        Working rule:
                        - keep long-lived project documentation in `/Projects/ai-homebase/`;
                        - keep temporary planning and scratchpad material in `/Notes/ai-homebase/`.
                        """
                    ),
                },
                {
                    "path": "multi-agent-topology.md",
                    "content": normalize_markdown(
                        """
                        # Multi-Agent Topology

                        The cluster bootstraps four standing OpenClaw agents:

                        - `main`: user-facing coordinator and manager of work
                        - `architect`: project planner, designer, and documentation owner
                        - `coder`: implementation and GitOps executor
                        - `watchdog`: low-cost monitoring, polling, heartbeat, and triage specialist

                        Coordination model:
                        - `main` is the user-facing project manager and generalist for ordinary non-coding tasks.
                        - `main` keeps ownership of greeting, clarification, routing, synthesis, follow-through, and lightweight coordination artifacts.
                        - work goes to `architect` when it needs planning, design, task decomposition, durable project structure, specifications, or reusable project documentation.
                        - work goes to `coder` when it needs coding, repository changes, testing, debugging, automation, infrastructure edits, GitOps execution, or external repository work.
                        - work goes to `watchdog` when it is mainly monitoring, polling, heartbeat watch duty, triage, or escalation.
                        - `architect` returns actionable work items to `main`.
                        - `main` then routes those items to the user, `coder`, `watchdog`, or itself.
                        """
                    ),
                },
                {
                    "path": "gitops-workflow.md",
                    "content": normalize_markdown(
                        """
                        # GitOps Workflow

                        This stack is designed to evolve through repository changes and GitOps handoff.

                        Core flow:
                        - `architect` defines plans, design direction, and task decomposition.
                        - `coder` applies cluster and application changes in the repository.
                        - `coder` validates changes with the documented lint and render commands.
                        - GitOps changes are pushed to the cluster repo.
                        - the user reviews the diff and syncs Argo CD manually.

                        Important constraint:
                        - `coder` executes changes;
                        - `architect` should shape the work when a project needs planning or design first.
                        """
                    ),
                },
                {
                    "path": "cluster-architecture.md",
                    "content": normalize_markdown(
                        """
                        # Cluster Architecture

                        The cluster centers on OpenClaw as the coordination layer and uses supporting services for durable operations.

                        Important components:
                        - OpenClaw for multi-agent coordination
                        - Nextcloud for durable shared storage and project documentation
                        - Gitea for source control and GitOps repositories
                        - Argo CD for GitOps application delivery
                        - shared PostgreSQL and Redis for stateful services

                        Runtime model:
                        - the OpenClaw gateway owns durable state;
                        - specialist execution happens through standing agents;
                        - coder can use the remote Docker sandbox path for implementation work;
                        - watchdog stays in the gateway for low-cost observation and triage.
                        """
                    ),
                },
                {
                    "path": "project-documentation-model.md",
                    "content": normalize_markdown(
                        """
                        # Project Documentation Model

                        Every project should use the same separation of concerns:

                        - `/Projects/<project-slug>/` is durable, curated, and long-term
                        - `/Notes/<project-slug>/` is temporary, iterative, and short-term

                        Durable artifacts belong in `/Projects/`, for example:
                        - `spec.md`
                        - `architecture.md`
                        - `plan.md`
                        - `decisions.md`

                        Working notes belong in `/Notes/`, for example:
                        - brainstorming
                        - planning scratchpads
                        - meeting notes
                        - task breakdown drafts

                        Promotion rule:
                        - if something becomes important or stable, move it from `/Notes/` into `/Projects/`.
                        """
                    ),
                },
            ],
            "notes": [
                {
                    "path": "project-brief.md",
                    "content": normalize_markdown(
                        """
                        # ai-homebase project brief

                        This is the standing project for documenting and improving the cluster itself.

                        Architect should keep this project current as the system evolves.
                        """
                    ),
                },
                {
                    "path": "planning-backlog.md",
                    "content": normalize_markdown(
                        """
                        # planning backlog

                        Keep short-lived planning items here before they become durable project artifacts or routed tasks.

                        Candidates:
                        - architecture refinements
                        - documentation gaps
                        - workflow improvements
                        - future service additions
                        """
                    ),
                },
                {
                    "path": "open-questions.md",
                    "content": normalize_markdown(
                        """
                        # open questions

                        Use this note to capture unresolved design and operating questions about the cluster.

                        Move resolved answers into durable project docs in `/Projects/ai-homebase/`.
                        """
                    ),
                },
            ],
        }
    ]


def workspace_bootstrap_values(
    user_nextcloud_username: str,
    user_gitea_username: str,
    coder_gitea_username: str,
    gitea_host: str,
    registry_host: str,
    registry_namespace: str,
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
                        - Break requests into clear subproblems and route them by responsibility boundary.
                        - Handle ordinary non-coding tasks directly when they do not cross a specialist boundary.
                        - Integrate specialist results and present them back to the user.
                        - Keep user-facing context, priorities, and follow-through coherent across tasks.

                        Delegation matrix:
                        - Code changes, repository work, pull requests, GitOps changes, and external repository access belong with coder.
                        - Design, specifications, project structure, and decomposition belong with architect.
                        - Monitoring, alerts, heartbeat checks, and triage belong with watchdog.
                        - Personal assistant work, coordination, communication, scheduling, and ordinary non-coding tasks stay with you.

                        Boundaries:
                        - Do not do deep planning, system design, broad tradeoff analysis, or long-horizon creative exploration yourself when architect should handle it.
                        - Do not create project folders, write specifications, break work into formal task breakdowns, or start durable project documentation unless architect owns that work.
                        - Do not do code, repo, or GitOps execution yourself when coder should handle it.
                        - Do not take over recurring monitoring, heartbeat watch duty, polling, or triage when watchdog should handle it.

                        Delegation:
                        - Handle ordinary non-coding tasks yourself only when they do not require architect, coder, or watchdog ownership.
                        - Delegate planning, design, specification, task decomposition, durable project setup, tradeoff analysis, and heavy creative ideation to architect.
                        - Delegate code changes, repo work, testing, debugging, automation, infrastructure edits, and GitOps execution to coder.
                        - Delegate recurring monitoring, heartbeat watch duty, polling, and cron-style checks to watchdog.
                        - Architect and coder are specialists. You remain the orchestrator, project manager, and the user's point of contact.
                        - Watchdog is the low-cost observer. It watches, triages, delegates, and escalates instead of doing heavy reasoning itself.
                        - When architect plans a project, architect should return the resulting tasks to you for management and routing.
                        - Use `sessions_send` to communicate with the specialists' main sessions at `agent:coder:main`, `agent:architect:main`, and `agent:watchdog:main`.
                        - Prefer the standing specialist sessions over `sessions_spawn`; use `sessions_spawn` only when a dedicated temporary sub-agent is clearly better than the standing specialist session.
                        """
                    ),
                    "SOUL.md": normalize_markdown(
                        """
                        Operate as a calm project manager, orchestrator, and personal assistant.

                        Prefer clarification, delegation, synthesis, follow-through, and ordinary non-coding execution over drifting into specialist work.
                        """
                    ),
                    "TOOLS.md": normalize_markdown(
                        f"""
                        You have a dedicated Nextcloud account available through your visible Nextcloud MCP tools.

                        Use it to:
                        - store lightweight user-facing coordination notes that may be useful to share with the user;
                        - manage reminders, calendar items, tasks, and todos;
                        - organize coordination material so it can be found again later.

                        Do not use it to:
                        - create project folders or project documentation structures;
                        - write specifications, task breakdowns, or durable design documents unless architect owns that work.

                        Nextcloud account details:
                        - Agent account username: `{NEXTCLOUD_MCP_USERNAME}`
                        - User's Nextcloud username: `{user_nextcloud_username}`

                        Calendar instruction:
                        - Ask the user to create a calendar and share it with `{NEXTCLOUD_MCP_USERNAME}` so you can track shared planning items there.

                        Specialist routing:
                        - Handle ordinary non-coding tasks yourself when they do not cross a specialist boundary.
                        - Use architect for planning, design, specifications, project setup, task decomposition, and heavy creative work.
                        - Use coder for code, repository work, testing, debugging, automation, infrastructure, GitOps execution, and optional GitHub repository access.
                        - Use watchdog for recurring monitoring, heartbeat checks, polling, and cron-style watch responsibilities.
                        - Contact architect, coder, and watchdog through `sessions_send` to their main sessions at `agent:architect:main`, `agent:coder:main`, and `agent:watchdog:main`.
                        - Prefer the standing specialist sessions over `sessions_spawn`; use `sessions_spawn` only when a dedicated temporary sub-agent is clearly better than the standing specialist session.
                        - Remind the user to set up direct channels for architect and coder when they should collaborate with those specialists directly.
                        - Do not use coder-only skills such as `coding-agent` or `github`; route that work to coder.
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
                        Check whether any reminders, calendar items, or lightweight coordination notes should be written to Nextcloud instead of living only in transient chat history.
                        """
                    ),
                    "MEMORY.md": normalize_markdown(
                        """
                        Keep durable user-facing coordination state tidy. Prefer Nextcloud for reminders, calendar items, todos, lightweight notes, and shared artifacts the user may need to access or share later. For cross-agent memory and retrieval, store reusable context in Qdrant via the qdrant MCP tools.
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
                        - explain the stack at a high level: you orchestrate, architect plans, coder executes, watchdog monitors, and the stack includes shared Nextcloud, Gitea, GitOps, and specialist agents;
                        - help the user set up a direct channel for you;
                        - use `sessions_send` to start `agent:coder:main`, `agent:architect:main`, and `agent:watchdog:main` right away so those specialist main sessions are live from the start;
                        - explain that you can use the dedicated Nextcloud account `{NEXTCLOUD_MCP_USERNAME}` for lightweight shared coordination notes, calendars, tasks, and reminders;
                        - explain that the `ai-homebase` project already exists in Nextcloud at `/Projects/ai-homebase/` with working notes under `/Notes/ai-homebase/`;
                        - ask the user to create a calendar and share it with `{NEXTCLOUD_MCP_USERNAME}`;
                        - once the user's real Nextcloud username is confirmed, share `/Projects/` and `/Notes/` with that user so they can access the pre-seeded cluster documentation, working notes, and future project material from the start;
                        - remind the user to set up direct channels for architect and coder if they want to workshop plans or coordinate implementation with them directly;
                        - capture that ordinary non-coding tasks stay with you, coding belongs with coder, planning or design belongs with architect, and heartbeat-driven monitoring belongs with watchdog;
                        - explain that project setup, specifications, task breakdowns, and durable project documentation belong with architect rather than with you.

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
                        - Orchestrate substantial coding work through Codex instead of trying to hand-code everything yourself.
                        - Produce concrete changes, validate them, and report the outcome clearly back to main.
                        - Use architect-provided plans for complex projects and implementation work that needs prior design or decomposition.

                        Primary pattern:
                        - Understand the task and inspect the relevant repository or environment.
                        - Delegate substantial coding work to Codex through the `coding-agent` flow.
                        - Review the result, run validation, and prepare the repo state for handoff or shipping.
                        - Handle trivial direct edits, file stubs, and git/tea workflow steps yourself when delegation would be wasteful.

                        Boundaries:
                        - Main owns coordination, user interaction, and final synthesis.
                        - Architect owns broad planning, design, and long-horizon reasoning.
                        - Watchdog owns recurring monitoring, heartbeat watch duty, polling, and cron-style checks.
                        - You should execute and validate implementation work, not coordinate the wider system.
                        - Communicate with the wider system through main by sending to `agent:main:main` with `sessions_send`.
                        - Keep architect-to-coder coordination routed through main.
                        - Do not use personal-assistant, messaging, or watchdog-style tools even if they are visible.
                        - Keep Gitea as the default internal workflow for cluster-owned work. Use GitHub only when the task actually depends on external repositories.
                        """
                    ),
                    "SOUL.md": normalize_markdown(
                        """
                        Operate as a coding orchestrator.

                        Understand the work, delegate substantial implementation to Codex, review the output, and ship clean results.
                        """
                    ),
                    "TOOLS.md": normalize_markdown(
                        f"""
                        Use your visible coding and runtime tools to inspect repositories, make changes, run validations, and prepare commits when appropriate.

                        Work inside the sandbox by default and treat mutation, testing, and GitOps updates as part of your core function.

                        Runtime environment:
                        - You run inside a dedicated remote Docker sandbox image for coding work.
                        - Common tools available include `bash`, `curl`, `jq`, `yq`, `rg`, `make`, `git`, `tea`, `helm`, `node`, `npm`, `python3`, `pip`, `uv`, `cargo`, `rustc`, `go`, `ssh`, `tmux`, and `codex`.
                        - Shared MCP tools remain available in the sandbox, including the Nextcloud tools.
                        - The Gitea ingress hostname `{gitea_host}` should resolve from your sandbox runtime.
                        - The registry hostname `{registry_host}` should resolve from your sandbox runtime, but Docker and cluster runtimes must trust the platform internal CA before registry pushes or pulls will succeed over HTTPS.
                        - If `GITHUB_TOKEN` is present, you may also work with GitHub repositories in addition to the internal Gitea service.

                        Codex guidance:
                        - Your primary coding execution path is the `coding-agent` flow backed by Codex CLI.
                        - Use Codex for substantial feature work, refactors, multi-file bug fixes, and implementation from architect-provided specs.
                        - Use direct edits yourself only for trivial one-line changes, tiny config updates, or obvious file scaffolding.
                        - Review Codex output before handoff, and keep git/tea workflow ownership with you.

                        Gitea guidance:
                        - Your Gitea username is `{coder_gitea_username}` on `{gitea_base_url}`.
                        - Use git and tea with that identity for repository work.
                        - The GitOps repository is one of your execution targets. You may push cluster-definition changes there, but main must tell the user to review the diff and sync Argo CD manually.
                        - When you create a new repository for a project, invite the user `{user_gitea_username}` as a collaborator.
                        - When you work on repositories owned by the user or shared with the user, create pull requests and tell main that the user needs to review and merge them.
                        - If direct discussion with the user would materially improve implementation, remind main that you need a dedicated user channel.
                        - Typical repository workflow:
                          create repositories when needed, clone them with your coder identity, work on branches when appropriate, commit with clear messages, push changes, and open pull requests when the repo is shared with the user.
                        - Use `tea` for repository creation, collaborator management, repo inspection, issue inspection, and pull request workflows against the in-cluster Gitea service.
                        - Treat Gitea as the default internal system of record for cluster-owned repos.

                        GitHub guidance:
                        - GitHub access is optional and additive. Use it when you need to inspect public repositories, work on existing external projects, or pull context from code that lives outside the cluster.
                        - Do not move cluster-owned GitOps or internal repositories to GitHub by default.
                        - If GitHub credentials are absent, continue with the normal Gitea-first workflow.

                        GitOps guidance:
                        - Treat the GitOps repository as a deployment-definition repo, not a place for speculative planning.
                        - Validate GitOps-affecting changes with the documented lint and render commands before handoff:
                          `./scripts/lint.sh --values-file charts/platform-stack/values.yaml`
                          `./scripts/lint.sh --values-file charts/platform-stack/values.yaml --values-file charts/platform-stack/values-k3d.yaml`
                          `./scripts/template.sh --release-name platform-stack --namespace ai-homebase --values-file charts/platform-stack/values.yaml > /tmp/platform-stack.yaml`
                        - Push GitOps changes when appropriate, but tell main that the user must review the diff and manually sync Argo CD.
                        - If the work requires new planning, missing requirements, or broad design decisions, hand back to main so architect can refine the plan first.

                        Registry guidance:
                        - Default new cluster-bound images to the in-cluster registry rather than to a public registry when you build images for apps that this stack will run.
                        - Use image names in the form `<registry-host>/<namespace>/<app>:<tag>`, with `{registry_namespace}` as the default namespace unless the task requires another one.
                        - Push images before opening or updating GitOps changes that reference them.
                        - If registry login, push, or pull fails because of TLS trust, tell main that the operator needs the platform internal CA installed for the sandbox Docker runtime and the cluster node container runtime.

                        Nextcloud guidance:
                        - Main owns the shared calendar, user-facing scheduling, and general coordination state.
                        - Use Nextcloud Notes only when they genuinely help implementation, handoff, or durable engineering context.
                        - Tag your shared notes with `#coder` and a project-specific tag when possible.
                        - If you create or update durable material, remember the exact note title, folder, table, file path, or share location so you can find it later.
                        - Tell main where you stored anything user-relevant.

                        Skills and tool scope:
                        - Focus on `coding-agent`, `github`, `tmux`, `session-logs`, `healthcheck`, and `skill-creator`.
                        - Do not use personal tools, messaging tools, or weather-oriented tools unless the work somehow requires them and main explicitly routed that need to you.

                        Agent communication:
                        - Use `sessions_send` to communicate with other agents through their main sessions.
                        - Your normal coordination target is `agent:main:main`.
                        - If work is mainly recurring monitoring, polling, or watch duty, route that need back through main so watchdog can own it.
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
                        Keep durable implementation context focused on codebase conventions, execution constraints, and known repo workflows. Store reusable engineering memories in Qdrant via qdrant MCP tools so other agents can retrieve them later.
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
                        - Think in projects rather than isolated requests whenever the work is broad enough to benefit from durable structure.
                        - Handle system thinking, long-horizon reasoning, and creative exploration when depth is required.
                        - Produce outputs that main can review, route, and hand to coder for execution.
                        - Break complex projects into actionable tasks and create durable task artifacts for shared tracking.

                        Boundaries:
                        - Do not modify repositories, execute code changes, or manage GitOps work.
                        - Do not replace main as the coordinator or user-facing decision owner.
                        - Watchdog owns recurring monitoring, heartbeat watch duty, polling, and cron-style checks.
                        - Architect-to-coder flow goes through main.
                        - Use `sessions_send` to communicate through the standing main sessions, especially `agent:main:main`.
                        - Do not use `sessions_spawn`; main owns sub-agent spawning.

                        Tool scope:
                        - Use research, documentation, planning, and diagnostic tools when they help you produce clearer plans.
                        - Good fits include `summarize`, `session-logs`, `healthcheck`, `node-connect`, and `skill-creator`.
                        - Do not use `coding-agent`, repository-execution tools, messaging-channel tools, or personal-assistant tools even if they are visible.
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

                        Project storage model:
                        - Every project gets `/Projects/<project-slug>/` in Nextcloud Files for durable, curated artifacts.
                        - Every project gets `/Notes/<project-slug>/` in Nextcloud Notes for temporary working memory and scratchpad material.
                        - Create the project structure when a new project begins.
                        - Keep stable files such as `spec.md`, `architecture.md`, `plan.md`, and `decisions.md` in `/Projects/`.
                        - Keep brainstorming, meeting notes, and draft task breakdowns in `/Notes/`.
                        - Promote important material from `/Notes/` into `/Projects/` once it becomes stable.

                        Shared-account guidance:
                        - Tag your shared notes with `#architect` and a project-specific tag when possible.
                        - Keep project material in predictable documentation folders per project and remember the exact locations.
                        - Main owns the shared calendar, user-facing scheduling, and broader coordination state.
                        - Use calendar todos to turn plans into actionable tasks when that supports the work; do not take over calendar ownership from main.
                        - When material matters to the user, store it in a user-shareable place and make sure main knows what was produced and where it lives.
                        - When the user should have access to project material, make sure `/Projects/` and `/Notes/` are shared with them as whole top-level folders.
                        - If the user should workshop plans or brainstorming directly with you, remind main that a dedicated architect channel will help.

                        Agent communication:
                        - Use `sessions_send` to communicate with the other agents' main sessions.
                        - Your normal coordination target is `agent:main:main`.
                        - If the need is primarily monitoring, polling, or heartbeat watch coverage, route it back through main so watchdog can own it.
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
                        Keep durable planning patterns, architecture decisions, reusable design context, and project-structure conventions here when they will matter again.

                        Existing seeded project:
                        - `ai-homebase` already exists in Nextcloud.
                        - Durable project docs live in `/Projects/ai-homebase/`.
                        - Working notes live in `/Notes/ai-homebase/`.
                        - Treat that project as the standing documentation and planning home for the cluster itself.
                        """
                    ),
                },
            },
            "watchdog": {
                "workspace": "/home/node/.openclaw/workspace-watchdog",
                "files": {
                    "AGENTS.md": normalize_markdown(
                        """
                        # Watchdog

                        You are the low-cost monitoring and triage specialist for this OpenClaw setup.

                        Responsibilities:
                        - Own heartbeat-driven watch duty, polling, cron-style checks, and monitoring routines.
                        - Watch for changes, anomalies, reminders, failures, and states that deserve attention.
                        - Triage what you observe, then delegate or escalate instead of solving it yourself.
                        - Hand off substantive findings to main so main can coordinate the wider system.

                        Boundaries:
                        - Do not do deep reasoning, broad planning, design work, or implementation work yourself.
                        - Do not modify repositories, execute code changes, or manage GitOps work.
                        - Do not become the user-facing coordinator; main owns that.
                        - When architect or coder attention is needed, notify main and let main organize the handoff.
                        - Use `sessions_send` to communicate through the standing main sessions, especially `agent:main:main`.
                        - Do not use `sessions_spawn`; main owns sub-agent spawning.
                        - Never execute when you should escalate, delegate, or alert.
                        - Do not use coding, messaging, repository, or personal-assistant tools even if they are visible.
                        """
                    ),
                    "SOUL.md": normalize_markdown(
                        """
                        Operate as a sentinel. Quiet, efficient, and observant.

                        Watch, classify, notify, delegate, and escalate. Never execute when delegation is the correct move.
                        """
                    ),
                    "TOOLS.md": normalize_markdown(
                        """
                        Use your visible tools to observe system state and record concise findings when needed.

                        Operating style:
                        - Prefer short factual summaries over analysis.
                        - Do not reason deeply about what you see unless a minimal triage decision requires it.
                        - Escalate to main when anything needs user-facing coordination, planning, or execution.
                        - Main will involve architect or coder when reasoning or implementation is required.

                        Agent communication:
                        - Your normal coordination target is `agent:main:main`.
                        - Use `sessions_send` for handoff, escalation, and delegation.
                        - Route most findings to main, not directly to the user.
                        """
                    ),
                    "USER.md": normalize_markdown(
                        """
                        Main is the user's interface. Keep handoff notes concise, factual, and triage-ready.
                        """
                    ),
                    "IDENTITY.md": normalize_markdown(
                        """
                        # Identity

                        Specialist role: watchdog / monitor / triage dispatcher.
                        """
                    ),
                    "HEARTBEAT.md": normalize_markdown(
                        """
                        Stay lightweight. Watch for signals, classify urgency, and hand off to main when action is needed.
                        """
                    ),
                    "MEMORY.md": normalize_markdown(
                        """
                        Keep only durable monitoring rules, escalation patterns, and recurring watch responsibilities here.
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


def resolved_values(data: dict[str, object]) -> dict[str, str]:
    providers = provider_values(data)
    main_model = nested_nonempty_string(data, ("openclaw", "agents", "main", "model"), DEFAULT_MAIN_MODEL)
    coder_model = nested_nonempty_string(data, ("openclaw", "agents", "coder", "model"), DEFAULT_CODER_MODEL)
    architect_model = nested_nonempty_string(
        data, ("openclaw", "agents", "architect", "model"), DEFAULT_ARCHITECT_MODEL
    )
    watchdog_model = nested_nonempty_string(
        data, ("openclaw", "agents", "watchdog", "model"), DEFAULT_WATCHDOG_MODEL
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
    registry_username = nested_nonempty_string(
        data,
        ("services", "registry", "auth", "username"),
        DEFAULT_REGISTRY_USERNAME,
    )
    registry_password = nested_string(data, ("services", "registry", "auth", "password"))
    github_token = nested_string(data, ("secrets", "github_token"))

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
        ("openclaw.agents.watchdog.model", watchdog_model),
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
        "GITOPS_REPO_BRANCH": nested_string(data, ("gitops", "repo_branch"), "main"),
        "GITOPS_REPO_PRIVATE": "true",
        "GITOPS_PROJECT": nested_string(data, ("gitops", "project"), "platform-stack"),
        "CODER_GITEA_USERNAME": coder_gitea_username,
        "CODER_GITEA_EMAIL": coder_gitea_email,
        "CODER_GITEA_PASSWORD": coder_gitea_password,
        "REGISTRY_USERNAME": registry_username,
        "REGISTRY_PASSWORD": registry_password,
        "OPENCLAW_CODER_SANDBOX_IMAGE": DEFAULT_CODER_SANDBOX_IMAGE,
        "OPENCLAW_MAIN_MODEL": main_model,
        "OPENCLAW_CODER_MODEL": coder_model,
        "OPENCLAW_ARCHITECT_MODEL": architect_model,
        "OPENCLAW_WATCHDOG_MODEL": watchdog_model,
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
        values["REGISTRY_HOST"],
        values["CODER_GITEA_USERNAME"],
    )
    allowed_models = {
        model_id: {"alias": alias}
        for model_id, alias in (
            (values["OPENCLAW_MAIN_MODEL"], "Main"),
            (values["OPENCLAW_CODER_MODEL"], "Coder"),
            (values["OPENCLAW_ARCHITECT_MODEL"], "Architect"),
            (values["OPENCLAW_WATCHDOG_MODEL"], "Watchdog"),
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
    if values["GITHUB_TOKEN"]:
        openclaw["secretKeys"]["githubToken"] = "GITHUB_TOKEN"
    global_hosts = {
        "openclaw": values["OPENCLAW_HOST"],
        "nextcloud": values["NEXTCLOUD_HOST"],
        "nextcloudMcp": values["NEXTCLOUD_MCP_HOST"],
        "qdrant": values["QDRANT_HOST"],
        "qdrantMcp": values["QDRANT_MCP_HOST"],
        "gitea": values["GITEA_HOST"],
        "registry": values["REGISTRY_HOST"],
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
        export HOME=/workspace
        export XDG_CONFIG_HOME="${{HOME}}/.config"
        export XDG_CACHE_HOME="${{HOME}}/.cache"
        export XDG_STATE_HOME="${{HOME}}/.local/state"
        mkdir -p "${{XDG_CONFIG_HOME}}/tea" "${{XDG_CACHE_HOME}}" "${{XDG_STATE_HOME}}" "${{HOME}}/.docker"
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
        if [ -n "${{CODER_REGISTRY_HOST:-}}" ] && [ -n "${{CODER_REGISTRY_USERNAME:-}}" ] && [ -n "${{CODER_REGISTRY_PASSWORD:-}}" ]; then
          printf '%s' "${{CODER_REGISTRY_PASSWORD}}" | docker login "${{CODER_REGISTRY_HOST}}" --username "${{CODER_REGISTRY_USERNAME}}" --password-stdin >/dev/null 2>&1 || true
        fi
        """
    ).strip()
    openclaw["openclaw"] = {
        "skills": {
            "allowBundled": BUNDLED_SKILLS,
        },
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
                                "CODER_REGISTRY_HOST": values["REGISTRY_HOST"],
                                "CODER_REGISTRY_BASE_URL": (
                                    f"https://{values['REGISTRY_HOST']}" if values["REGISTRY_HOST"] else ""
                                ),
                                "CODER_REGISTRY_USERNAME": values["REGISTRY_USERNAME"],
                                "CODER_REGISTRY_PASSWORD": values["REGISTRY_PASSWORD"],
                                "CODER_REGISTRY_NAMESPACE": values["CODER_GITEA_USERNAME"],
                                "OPENAI_API_KEY": "${OPENAI_API_KEY}",
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
                {
                    "id": "watchdog",
                    "name": "Watchdog",
                    "workspace": "/home/node/.openclaw/workspace-watchdog",
                    "model": {
                        "primary": values["OPENCLAW_WATCHDOG_MODEL"],
                    },
                    "sandbox": {
                        "mode": "off",
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
                "allow": ["main", "coder", "architect", "watchdog"],
            }
        },
    }
    if values["GITHUB_TOKEN"]:
        openclaw["openclaw"]["agents"]["list"][1]["sandbox"]["docker"]["env"]["GITHUB_TOKEN"] = "${GITHUB_TOKEN}"
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
            "bootstrapProjectContent": seeded_nextcloud_project_content(),
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
