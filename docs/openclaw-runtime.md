# OpenClaw Runtime Contract

OpenClaw is the stack's multi-agent gateway. This page keeps the runtime-specific contract in one place so the configuration and services references can stay focused.

## Runtime Shape

The supported target posture is:

- OpenClaw gateway runs in Kubernetes.
- Docker/browser sandboxes run on a single-purpose Incus VM outside Helm.
- Gateway pod and Incus VM share the same OpenClaw state tree at `/home/node/.openclaw`.
- Sandbox `/workspace` binds into that durable state and remains writable.
- Ingress hostnames that sandboxes call are resolved into the Incus host listener by the sandbox helper scripts.

The shared state source is target-specific:

- `k3d`: `~/.local/state/ai-homebase/openclaw-state`
- `k3s`: `/var/lib/ai-homebase/openclaw-state`

Do not make `/workspace` a tmpfs in sandbox images. That masks the writable bind mount and breaks coder state, Git state, Codex state, and generated worktrees.

## Gateway Image

Both `k3d` and `k3s` use the repo-managed gateway image `openclaw-remote-docker:trixie-slim`. Bootstrap builds it locally and makes it available to the active node runtime before Helm expects the Deployment to start. The image keeps `pullPolicy: IfNotPresent` because this is a bootstrap-owned local image path.

The repo-managed image adds the runtime tools the seeded agents expect, including Docker CLI, SSH, Git, `gh`, `tea`, `tmux`, Node, `npm`, `summarize`, `jq`, Python, `rg`, `tokscale`, and OpenClaw runtime bridge assets.

## Remote Docker

`openclaw.remoteDocker.*` wires the gateway pod to the Incus VM over Docker's `ssh://` transport. The Secret named by `openclaw.remoteDocker.ssh.secretName` must contain non-empty `id_ed25519` and `known_hosts` keys.

The standard sandbox VM helpers are:

```bash
./scripts/incus-vm-up.sh --vm-name openclaw-sandbox
./scripts/k3s-homelab-sandbox-up.sh --bootstrap-config bootstrap.local.toml
```

The k3d and k3s bootstrap wrappers auto-discover the generated Incus connection env file when it exists and render the concrete remote Docker endpoint into the first install.

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

On `k3s`, bootstrap also imports the CA into the Incus VM's Docker registry trust path for the rendered registry hostname and refreshes the VM trust store when the VM is reachable.

## Seeded Agents

Bootstrap seeds explicit agents:

- `main`: user-facing coordinator
- `architect`: planning, design, specs, and durable project structure
- `coder`: code, repos, images, GitOps, and execution
- `archivist`: Qdrant/Memgraph memory stewardship
- `watchdog`: low-cost monitoring and scheduled triage
- `auditor`: sparse high-judgment review

Agent model selections come from `bootstrap.local.toml` under `[openclaw.agents.<id>]`. `coder` also accepts `codex_model` for the Codex CLI runtime inside its sandbox.

Workspace seed files live under `charts/openclaw/files/workspaces/`. Keep those files written from the bootstrapped agent's in-cluster perspective; avoid maintainer-only rationale there.

## MCP Bridges

HTTP-backed MCP servers should be defined at gateway level under `openclaw.openclaw.mcp.servers.<name>` and launched through:

```text
/opt/openclaw-runtime/mcp/mcp-http-bridge.mjs
```

Use dual `--url` arguments:

1. in-cluster Service URL for the gateway pod
2. ingress URL for Docker sandboxes in the Incus VM

This is the standard pattern for Nextcloud MCP and Qdrant MCP. Keep bridges outside agent workspaces so every agent sees the same runtime path.

## Memory Surfaces

OpenClaw's builtin memory plugin is disabled with `plugins.slots.memory=none`. Durable recall flows through:

- Qdrant MCP for semantic memories
- Memgraph for graph structure curated by archivist
- Nextcloud `/Projects/<slug>/` for shared project files and runbooks
- local seeded workspace files for short-term agent continuity

The memory schemas live in [qdrant-memory-schema.md](./qdrant-memory-schema.md) and [knowledge-graph-schema.md](./knowledge-graph-schema.md).
