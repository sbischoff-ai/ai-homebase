# OpenClaw Runtime Contract

OpenClaw is the stack's multi-agent gateway. This page keeps the runtime-specific contract in one place so the configuration and services references can stay focused.

## Runtime Shape

The supported target posture is:

- OpenClaw gateway runs in Kubernetes.
- Docker/browser sandboxes run on a single-purpose Incus VM outside Helm.
- Gateway pod and Incus VM share the same OpenClaw state tree at `/home/node/.openclaw`.
- Sandbox `/workspace` binds into that durable state and remains writable.
- Sandbox tool state lives under `/workspace/.home`, which is the writable home and XDG root for regular sandbox sessions.
- Ingress hostnames that sandboxes call are resolved into the Incus host listener by the sandbox helper scripts.
- Sandboxed agents use ingress-facing HTTPS URLs for Qdrant, Qdrant MCP, and Nextcloud MCP; gateway sessions use in-cluster Service URLs where those are more reliable.

The shared state source is target-specific:

- `k3d`: `~/.local/state/ai-homebase/openclaw-state`
- `k3s`: `/var/lib/ai-homebase/openclaw-state`

Do not make `/workspace` a tmpfs in sandbox images. That masks the writable bind mount and breaks coder state, Git state, Codex state, and generated worktrees.

## Gateway Image

Both `k3d` and `k3s` use the repo-managed gateway image `openclaw-remote-docker:trixie-slim`. Bootstrap builds it locally and makes it available to the active node runtime before Helm expects the Deployment to start. The image keeps `pullPolicy: IfNotPresent` because this is a bootstrap-owned local image path.

The repo-managed image adds the runtime tools the seeded agents expect, including Docker CLI, SSH, Git, `gh`, `tea`, `tmux`, Node, `npm`, `summarize`, `jq`, Python, `rg`, `tokscale`, and OpenClaw runtime bridge assets.
The gateway and sandbox image builds pin `tea` to a stable tagged release instead of building an unreleased development head so the seeded login config behaves predictably. OpenClaw runtime config provides canonical `OPENCLAW_HOME` and `OPENCLAW_STATE_DIR` values for durable tool state; the gateway image also wraps `tea` and `summarize` so agent exec commands use writable state under `/home/node/.openclaw` even when OpenClaw sanitizes inherited XDG path variables. Sandboxed agents still receive explicit writable `HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, and `XDG_STATE_HOME` values under `/workspace/.home`; for `architect`, those paths let `tea` read the seeded reviewer login from the durable workspace home.

## Remote Docker

`openclaw.remoteDocker.*` wires the gateway pod to the Incus VM over Docker's `ssh://` transport. The Secret named by `openclaw.remoteDocker.ssh.secretName` must contain non-empty `id_ed25519` and `known_hosts` keys. Bootstrap also seeds those same SSH materials into coder's workspace-local `~/.ssh` so the coder sandbox can talk to the remote Docker endpoint through `DOCKER_HOST=ssh://...` without binding `/var/run/docker.sock`.

The coder sandbox image includes the Docker CLI. The gateway and coder sandbox both rely on the same remote Docker endpoint; the difference is that the gateway receives SSH material from the Kubernetes Secret, while the coder sandbox reads the workspace-local copy seeded during bootstrap.

The standard sandbox VM helpers are:

```bash
./scripts/incus-vm-up.sh --vm-name openclaw-sandbox
./scripts/bootstrap-stack.sh --profile k3s --bootstrap-config bootstrap.local.toml
```

The `k3d` and `k3s` bootstrap flow auto-discovers the generated Incus connection env file when it exists and renders the concrete remote Docker endpoint into the first install. On `k3s`, `bootstrap-stack.sh --profile k3s` reconciles both the sandbox VM and the default-on Gitea Actions runner VM before the shared apply and smoke phases run.

## Internal CA Trust

The stack uses cert-manager to create an internal root CA. After cert-manager creates `platform-stack-root-ca`, bootstrap exports the public `ca.crt` into the shared OpenClaw state tree and creates a combined CA bundle:

- `/home/node/.openclaw/certs/platform-stack-root-ca.crt`
- `/home/node/.openclaw/certs/ai-homebase-ca-bundle.crt`

The combined bundle includes the host system trust bundle plus the platform internal CA when available. The gateway and sandbox environments point common TLS clients at that bundle:

- `SSL_CERT_FILE`
- `REQUESTS_CA_BUNDLE`
- `NODE_EXTRA_CA_CERTS`
- `GIT_SSL_CAINFO`
- `CURL_CA_BUNDLE`

The gateway reads the bundle directly from `/home/node/.openclaw/certs/ai-homebase-ca-bundle.crt`. Gateway-side reviewer tool state also lives under that same durable tree: `OPENCLAW_STATE_DIR`, `GIT_CONFIG_GLOBAL`, and the `tea`/`summarize` wrappers point into `/home/node/.openclaw` so auth and state survive pod restarts without relying on the read-only image home or on XDG env inheritance into every exec child. During workspace seeding, bootstrap also copies it into each sandbox workspace at `/workspace/.openclaw-runtime/ai-homebase-ca-bundle.crt` so sandbox trust stays inside the workspace root instead of relying on an out-of-roots bind mount.

On `k3s`, bootstrap also imports the CA into the Incus VM's Docker registry trust path for the rendered registry hostname and refreshes the VM trust store when the VM is reachable.

## Seeded Agents

Bootstrap seeds explicit agents:

- `main`: user-facing coordinator
- `architect`: planning, design, specs, and durable project structure, with gateway-side main sessions and sandboxed non-main reviewer access to Gitea
- `coder`: code, repos, images, GitOps, and execution
- `archivist`: Qdrant/Memgraph memory stewardship
- `watchdog`: low-cost monitoring and scheduled triage
- `auditor`: sparse high-judgment review, with gateway reviewer access to Gitea; auditor sandboxing is off by default

Reviewer Gitea routing is runtime-specific:

- gateway reviewer token/bootstrap API calls and gateway-home `tea` checks use the in-cluster Gitea HTTP Service URL
- Docker sandbox reviewer `tea` and git sessions, currently architect non-main sessions, use the configured ingress hostname resolved through the Incus VM host overrides
- coder's durable sandbox `tea` login uses that same ingress hostname path, while gateway-side coder bootstrap calls still use the in-cluster Gitea HTTP Service URL

Do not expect cluster-internal DNS names to resolve inside Docker sandbox containers.
Bootstrap also mints dedicated tea API tokens for coder and reviewer, stores them in `coder-credentials` and `reviewer-credentials`, and passes them into the runtime. The password remains in those Secrets for git/basic-auth and for first-session fallback if a running OpenClaw pod has not yet been restarted onto the refreshed token values. The gateway now runs `reviewer-gitea-init.sh` during pod startup through a repo-managed wrapper, so reviewer `tea` and git access are repaired on every start instead of depending only on the post-deploy bootstrap hook. That setup seeds HTTPS git credentials in gateway reviewer state, the auditor workspace home, and the architect sandbox workspace home, and rewrites Gitea SSH clone URLs back onto the same HTTPS base so reviewer work does not depend on SSH reachability.

Coder auth state is repaired from that same gateway startup path. The live Docker sandbox container does not reliably receive Kubernetes Secret-backed env values such as `OPENAI_API_KEY`, `CODER_GITEA_TOKEN`, or `CODER_REGISTRY_PASSWORD`, so the repo-managed wrapper now runs `coder-workspace-init.sh` against the shared `workspace-coder/.home` tree before the first coder session starts. That seeds durable Codex auth, `tea` login state, git/basic-auth, and registry login without requiring a manual `codex login` inside the live sandbox. That startup repair path must keep coder's token bootstrap on the in-cluster Gitea service while writing the saved `tea` login against the sandbox-reachable ingress hostname. Coder token minting now waits for the user account to become auth-ready and retries duplicate-name cleanup the same way reviewer bootstrap does, so fresh installs do not fail on early `401` or reused token-name races.

Bootstrap also auto-approves the gateway-side CLI device scope upgrade that it needs for repo-managed OpenClaw writes such as cron seeding and smoke validation. That approval is only for the bootstrap-owned in-pod CLI identity. First-use pairing for a new browser or external operator device remains a separate manual approval step.
The seeded Codex config in that coder home now pins Codex CLI `0.122.0`, sets `approval_policy = "never"`, and sets `sandbox_mode = "danger-full-access"` because the coder agent is already running inside the dedicated Docker sandbox container. The coder image does not add a separate system `bwrap` package for an inner Linux sandbox layer. Coder invokes Codex through `openclaw-codex-run`, which starts long runs in `tmux`, captures Codex `--json` output under `/workspace/.home/.config/tokscale/headless/codex/`, and writes per-run metadata and Tokscale reports under `/workspace/.home/.local/state/openclaw-codex-runs/`.

Agent model selections come from `bootstrap.local.toml` under `[openclaw.agents.<id>]`. `coder` also accepts `codex_model` and `codex_elevated_model` for the Codex CLI runtime inside its sandbox; the shipped defaults are `openai/gpt-5.3-codex` and `openai/gpt-5.5`. The shipped bootstrap defaults now span three providers: `main` uses `anthropic/claude-sonnet-4-6`, `coder` and `architect` use `openai/gpt-5.4`, `archivist` uses `openai/gpt-5.4-mini`, `watchdog` uses `openai/gpt-5.4-nano`, and `auditor` uses `anthropic/claude-opus-4-7`, with ordered OpenAI/Anthropic/Google fallbacks depending on agent role. An unmodified bootstrap config therefore needs `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, and `GEMINI_API_KEY`.
Heartbeat is configured explicitly rather than relying on OpenClaw's built-in default cadence: `agents.defaults.heartbeat.every=0m` disables standing heartbeats for every agent unless a specific agent overrides it, `main` also keeps `heartbeat.includeSystemPromptSection=false`, and `watchdog` is the standing heartbeat agent at `30m`. Runtime-created `HEARTBEAT.md` templates are not authoritative for scheduling; the rendered heartbeat interval is.

Workspace seed files live under `charts/openclaw/files/workspaces/`. Keep those files written from the bootstrapped agent's in-cluster perspective; avoid maintainer-only rationale there.

## MCP Bridges

HTTP-backed MCP servers should be defined at gateway level under `openclaw.openclaw.mcp.servers.<name>` and launched through:

```text
/opt/openclaw-runtime/mcp/mcp-http-bridge.mjs
```

Use dual `--url` arguments:

1. in-cluster Service URL for the gateway pod
2. ingress URL for Docker sandboxes in the Incus VM

This is the standard pattern for Nextcloud MCP and Qdrant MCP. The chart renders those URL placeholders into concrete Service and ingress URLs in `openclaw.json`, while the Nextcloud MCP auth header remains a Secret-backed env placeholder. Keep bridges outside agent workspaces so every agent sees the same runtime path, and keep the repo-managed sandbox images shipping that same bridge path so sandboxed agents can launch MCP tools from inside the Incus VM.

The sandboxed `coder`, `architect`, and `archivist` agents set `tools.profile=full`, and the global sandbox tool policy explicitly `alsoAllow`s `nextcloud__*`, `qdrant__*`, `nc_*`, and `qdrant-*`. Current OpenClaw releases apply sandbox tool policy after bundled MCP tools are materialized, so both pieces are required for Nextcloud and Qdrant MCP visibility in sandboxed sessions. Agent-specific deny lists still remove unrelated UI/browser tools where appropriate.

## Memory Surfaces

OpenClaw's builtin memory plugin is disabled with `plugins.slots.memory=none`. Durable recall flows through:

- Qdrant MCP for semantic memories
- Memgraph for graph structure curated by archivist
- Nextcloud `/Projects/<slug>/` for shared project files and runbooks
- local seeded workspace files for short-term agent continuity

Memgraph Bolt is reachable from Docker sandboxes through the ingress-nginx TCP service map on port `7687`, with `k3d` also mapping host port `7687` to the load balancer. The archivist sandbox therefore uses the rendered `MEMGRAPH_HOST`/`MEMGRAPH_PORT` values, not Kubernetes Service DNS.

The memory schemas live in [qdrant-memory-schema.md](./qdrant-memory-schema.md) and [knowledge-graph-schema.md](./knowledge-graph-schema.md).
