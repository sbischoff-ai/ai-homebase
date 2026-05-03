# OpenClaw chart notes

This chart deploys OpenClaw as a **single trusted-boundary, long-running gateway host** with durable state and the repo's standard ingress-on access model.

## What this chart configures by default

- **One replica** (`replicaCount: 1`) because the gateway owns mutable state.
- **Durable state** (`persistence.enabled: true`) mounted at `/home/node/.openclaw` and exported as `OPENCLAW_STATE_DIR`.
- For the supported remote-Docker posture, the `k3d` and `k3s` overlays switch that durable state to a shared `hostPath` so the gateway pod and the sandbox host see the same `/home/node/.openclaw` tree. OpenClaw binds sandbox workspaces from that state directory; if the two environments do not share it, sandboxed agents will see empty `/workspace` mounts.
- The shared sandbox contract keeps `/workspace` writable for sandboxed agents and must not overlay `/workspace` with `tmpfs`, or Docker will mask the durable workspace mount with a read-only staging area. Regular sandbox sessions use `/workspace` as the bound workdir and `/workspace/.home` as the durable writable home used for `HOME` and XDG state, and the regular sandbox image sets the `sandbox` user's passwd home there so tools that consult `/etc/passwd` instead of `$HOME` still land on writable state. The coder sandbox builds on that same contract for `CODEX_HOME`, git/tool state, and remote Docker SSH material.
- **Writable runtime tempdir** mounted at `/tmp` via `emptyDir` (`medium: Memory`) so non-root UID `1000` can always create OpenClaw startup temp paths (for example `/tmp/openclaw-1000`) even when the root filesystem is read-only.
- A rendered `openclaw.json` from chart values, written into `/home/node/.openclaw/openclaw.json` by the init container so the repo-managed bootstrap contract stays authoritative for a fresh cluster. The shipped main workspace path is the absolute `/home/node/.openclaw/workspace` to stay inside the PVC without duplicating `.openclaw` in the resolved path, and additional agents use sibling paths such as `/home/node/.openclaw/workspace-architect`, `/home/node/.openclaw/workspace-coder`, and `/home/node/.openclaw/workspace-watchdog`.
- A rendered `openclaw.cron` scheduler block in `openclaw.json` so the persistent gateway config carries the documented cron store and retention settings. Repo-managed recurring jobs are seeded separately after startup through the OpenClaw CLI rather than embedded directly in the config file, including the watchdog checks, weekly archivist graph grooming, the weekly auditor review, and daily wrap-up jobs for the standing desk agents.
- A workspace seeding step that refreshes the repo-managed role files inside each agent workspace and also copies the shared CA bundle into `<workspace>/.openclaw-runtime/ai-homebase-ca-bundle.crt` so sandbox trust stays inside the allowed workspace roots. `main` gets a seeded `BOOTSTRAP.md` plus the durable role files so the normal first-use ritual still has an entrypoint, while `architect`, `coder`, and `watchdog` start as ready specialists. This setup's `CURRENT.md`, `SURFACES.md`, and `daily/` files are repo-managed custom local continuity surfaces, so the seeded `AGENTS.md` files and skills explicitly point to them when they matter instead of assuming OpenClaw injects them automatically. Nextcloud paths are marked inline as `Nextcloud /Desk/...` and `Nextcloud /Projects/...` so agents do not have to infer the storage boundary from surrounding prose. Heartbeat scheduling is explicit in config: `agents.defaults.heartbeat.every=0m` disables standing heartbeats unless an agent overrides it, `main` also keeps `heartbeat.includeSystemPromptSection=false`, and only `watchdog` gets both a seeded `HEARTBEAT.md` and a default scheduled heartbeat. Runtime-created `HEARTBEAT.md` templates are not authoritative for scheduling; the rendered heartbeat interval is. Higher-cost standing agents keep persistence and handoff rules in `AGENTS.md` and skills instead of a default periodic heartbeat file.
- The container explicitly starts the gateway in the foreground through `/usr/local/bin/openclaw-gateway-start.sh`, which repairs reviewer Gitea auth state and coder workspace auth state first and then launches `node openclaw.mjs gateway --allow-unconfigured` without relying on a user-level service manager (for example `systemctl --user`).
- Gateway runtime env is pinned for Kubernetes (`OPENCLAW_GATEWAY_PORT`, `OPENCLAW_GATEWAY_BIND=0.0.0.0`, `OPENCLAW_HOME`, `OPENCLAW_STATE_DIR`, `OPENCLAW_CONFIG_PATH`) so bind/port/state paths are explicit inside the container.
- Gateway defaults for remote access:
  - `gateway.bind: lan`
  - `gateway.port: 18789`
  - `gateway.auth.mode: token`
  - `gateway.controlUi.enabled: true`
- `Service` defaults to `ClusterIP` on port `18789`.
- Startup probe defaults are intentionally tolerant (`initialDelaySeconds: 10`, `periodSeconds: 10`, `failureThreshold: 30`) so Kubernetes does not restart OpenClaw during slower cold starts.
- `Ingress` is enabled by default (`ingress.enabled: true`) so the service is reachable through the stack's standard hostname model.

## Required operator-provided secrets

You must provide a Kubernetes Secret that includes:

- `OPENCLAW_GATEWAY_TOKEN` (**mandatory**) for gateway authentication.
- The model provider keys required by your selected standing-agent routing. The shipped defaults require `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, and `GEMINI_API_KEY`.

Search-only keys such as `BRAVE_API_KEY` and `PERPLEXITY_API_KEY` enable built-in web search but do not by themselves make chat replies work.

If `openclaw.gateway.auth.mode=token`, Helm rendering fails unless `existingSecret` and `secretKeys.gatewayToken` are configured.

## Optional provider/search/tooling keys

Optional keys for additional providers and web-search tooling:

- `BRAVE_API_KEY`
- `PERPLEXITY_API_KEY`
- `GEMINI_API_KEY`
- `XAI_API_KEY`
- `MOONSHOT_API_KEY`

Use `secretKeys` for common direct mappings and/or `secretRefs` for arbitrary secret-to-env mappings.

## Default access posture

By default, OpenClaw is exposed internally only:

- `Service` type is `ClusterIP`.
- `ingress.enabled` is `true` by default.
- Access should normally come through the configured ingress hostname, for example `http://openclaw.homebase.local`, with direct service access reserved for debugging or tightly controlled internal use.

## Ingress and origin requirements

With ingress enabled by default, make sure all of the following stay aligned:

1. Ingress hostname (`ingress.hosts[*].host`, `ingress.defaultHost`, or `global.hosts.openclaw`).
2. TLS for that hostname (`ingress.tls`) when your environment requires HTTPS.
3. `openclaw.gateway.controlUi.allowedOrigins` to exact browser origin(s), for example:
   - `https://openclaw.example.com`
4. `openclaw.gateway.trustedProxies` to the ingress-controller source CIDRs or IPs that set forwarded headers for OpenClaw.

For non-loopback binds, wildcard origins are intentionally rejected.

When TLS terminates at the ingress controller, keep OpenClaw itself on HTTP and set `openclaw.gateway.trustedProxies` to the proxy addresses that forward `X-Forwarded-For` / `X-Real-IP`. For the repo's standard in-cluster nginx ingress posture, this is typically the pod CIDR used by the controller deployment.

## First-use auth and pairing behavior

- OpenClaw authenticates during the **WebSocket handshake** using token auth (or password if configured).
- On first connection from a new browser/device, OpenClaw may require one-time pairing approval.
- Approval flow:

```bash
openclaw devices list
openclaw devices approve <requestId>
```

If you do not have direct CLI access in the running pod, make sure you have another operational path to run those commands when pairing approval is required.

## Trust model

This deployment is intended for a **single trusted operator / household / team boundary**.
It is **not intended to be a hostile multi-tenant shared service**.

## Sandbox configuration

The chart renders `commands.*`, `tools.*`, `agents.defaults.*`, `agents.list[]`, `skills.*`, `mcp.*`, and `plugins.*` into `openclaw.json`. The shipped defaults set up Docker sandboxing with explicit `backend: "docker"` plus `docker.*` and `browser.*` fields, bootstrap the standing agents, set `agents.defaults.heartbeat.every = "0m"` so non-watchdog agents stay heartbeat-disabled unless explicitly overridden, enable `tools.agentToAgent` with `tools.sessions.visibility=all`, and force `plugins.slots.memory = "none"` so builtin OpenClaw memory tools stay disabled. The seeded workspace model is now intentionally skills-first: concise `AGENTS.md` and `TOOLS.md` files define role boundaries, seeded local continuity files such as `CURRENT.md`, `SURFACES.md`, and `daily/` keep persistent-workspace agents oriented across runs, and nested `<workspace>/skills/` directories carry procedure-heavy guidance such as Nextcloud coordination, worker definition packaging, Gitea/GitOps workflow, Memgraph curation, incident handling, verdict formatting, and read-only/review-oriented Gitea browsing. The seeded wording now marks Nextcloud paths inline as `Nextcloud /Desk/...` and `Nextcloud /Projects/...`, while local workspace files stay plain or explicitly `local` only where mixed-surface ambiguity would otherwise be realistic. The desk agents also get seeded daily wrap-up cron jobs that turn the ending user day into historical notes and then carry only still-relevant state forward in `CURRENT.md`; `main` applies the same pattern to shared Nextcloud `/Desk/current.md` and Nextcloud `/Desk/daily/`. The chart also assigns explicit per-agent `skills` allowlists so each agent sees only the relevant workspace and bundled skills. The bundled allowlist is `weather`, `healthcheck`, `node-connect`, `skill-creator`, `session-logs`, `tmux`, `summarize`, and `github`; `coding-agent` is not enabled because coder is already the execution agent. Workspace skills are repo-owned and hyphenated, while bundled skills keep OpenClaw's upstream identifiers. `main` is the user-facing project manager and generalist for ordinary non-coding tasks, but it should not create project folders, write specs, or do durable task decomposition. That work belongs with `architect`, which treats main sessions as gateway-side planning work and uses sandboxing only for non-main reviewer tasks, while `main` curates a runtime-created shared Nextcloud `/Desk/` surface for bounded short-term continuity and indexing. Gateway reviewer setup now points at the in-cluster Gitea HTTP Service, while sandboxed reviewer setup keeps using the configured ingress hostname because those Docker sessions run in the Incus VM outside Kubernetes. Private WIP belongs in local workspace files, shared quick recall belongs in Qdrant, and durable shared artifacts belong in Nextcloud. `coder` overrides the default sandbox image so it can execute repo and GitOps work with common developer tooling installed, plus Codex CLI and Docker CLI for delegated implementation and remote Docker workflows; the regular and coder sandbox images now default to canonical in-cluster registry refs rather than local tags, and coder guidance assumes separate GitOps and sandbox-images repos in Gitea. Coder remote Docker access now uses `DOCKER_HOST=ssh://...` plus workspace-local SSH material instead of binding `/var/run/docker.sock`, which keeps the setup compatible with current OpenClaw sandbox policy. GitHub access is optional and additive, while Gitea remains the default internal workflow. `watchdog` overrides sandboxing to `off` so it always runs in the gateway for low-cost heartbeat work, and it is the only standing agent that ships with a seeded `HEARTBEAT.md`. Frequent reactive polling should stay with `watchdog` or a dedicated low-cost worker rather than a frontier standing agent. Because MCP-injected tools are not reliably hidden by per-agent deny rules, and because this stack standardizes on Qdrant for cross-agent recall, the chart now relies on the shared Qdrant MCP surface plus seeded workspace instructions instead of OpenClaw's builtin memory plugin. Sandboxed `coder`, `architect`, and `archivist` explicitly use `tools.profile=full`, and the global sandbox tool policy `alsoAllow`s `nextcloud__*`, `qdrant__*`, `nc_*`, and `qdrant-*`, so Nextcloud and Qdrant MCP tools remain visible in sandboxed sessions while per-agent deny lists still remove unrelated UI/browser tools. The chart also includes a local `node` launcher that bridges stdio MCP traffic to a remote HTTP MCP endpoint at `/opt/openclaw-runtime/mcp/mcp-http-bridge.mjs`, and keeps `remoteDocker.enabled=true` so the Deployment exports `DOCKER_HOST`/`HOME`, prepares an SSH directory at `remoteDocker.ssh.mountPath`, and mounts the referenced Secret for the standard remote Docker path.

Remote Docker mode now installs the Docker CLI into the pod via the `remoteDocker.cli.*` init-container flow. The main OpenClaw image still needs an SSH client because Docker's `ssh://` transport shells out to `ssh`.

If the OpenClaw image does not include `ssh`, the Deployment now fails early in init with an explicit error instead of starting a pod that cannot reach the remote Docker daemon.

This repo includes a repo-managed gateway Dockerfile at `images/openclaw-remote-docker/Dockerfile` that rebases the OpenClaw runtime onto a newer Debian userland so `mgconsole` works natively, while carrying `docker.io`, `openssh-client`, `git`, `gh`, wrapped `tea`, `tmux`, Node 22, `npm`, wrapped `summarize`, `jq`, Python with `requests`/`yaml`, and `ripgrep` for the supported skill and watchdog/session-logs posture. That image also ships `/usr/local/bin/openclaw-gateway-start.sh`, which creates writable OpenClaw state directories, runs gateway reviewer Gitea setup, auditor and architect workspace reviewer auth seeding, coder workspace auth seeding, and a non-fatal Nextcloud/Qdrant MCP `tools/list` prewarm on every pod start while keeping gateway startup non-fatal if Gitea, Codex, registry, or MCP dependencies are temporarily unavailable. It also ships `images/openclaw-sandbox-base/Dockerfile`, which uses the same newer glibc baseline and carries `gh`, wrapped `tea`, Node 22, `npm`, wrapped `summarize`, `jq`, `ripgrep`, `mgconsole`, Python `requests`/`yaml`/`neo4j`, bundled OpenClaw skill files, and the shared MCP HTTP bridge for the regular sandbox image, plus `images/openclaw-sandbox-coder/Dockerfile`, a coder-specific sandbox image layered on top of that base with `tmux`, Docker CLI, and Codex tooling. Sandbox CLI state is controlled through rendered OpenClaw `docker.env` values: `HOME` and XDG paths point into `/workspace/.home`, and `architect` also sets `GIT_CONFIG_GLOBAL` there so `tea` and git use the seeded durable workspace state. The post-gateway `scripts/bootstrap-openclaw-skills.sh` hook now validates bundled `github`, `summarize`, `tmux`, reviewer Gitea readiness, and coder workspace auth readiness against the current OpenClaw CLI and warns instead of failing the full bootstrap when optional credentials or binaries are absent. The Deployment also seeds a compatible `mgconsole` wrapper plus runtime libraries into the gateway pod at `/opt/memgraph-tools` so Memgraph access stays available even when the upstream OpenClaw image is still in use. Any sandbox image used for remote agent execution should expose the same shared MCP bridge path `/opt/openclaw-runtime/mcp/mcp-http-bridge.mjs` if you want MCP bridges to work inside sandboxed agents too.

The SSH Secret referenced by `remoteDocker.ssh.secretName` must include these exact keys:

- `id_ed25519` — the private key file used for the remote Docker SSH endpoint, and it must be present and non-empty.
- `known_hosts` — the SSH host key file for that endpoint, and it must be present and non-empty.

The `remote-docker-ssh-permissions` init container validates those two keys explicitly, copies only `id_ed25519` and `known_hosts` into an `emptyDir`, locks the directory and files down to OpenSSH-safe modes, and only then hands ownership to UID/GID `1000` before the main container starts so OpenSSH accepts the private key.

Security-context expectation for that init container:

- it runs as UID/GID `0` only for the permission-and-ownership preparation step;
- it keeps `allowPrivilegeEscalation: false` and a read-only root filesystem;
- it drops all Linux capabilities except `CHOWN`, which is still sufficient because the init container sets `0700`/`0600`/`0644` modes before `chown -R 1000:1000 /ssh-target` hands the prepared files to the main container;
- the main OpenClaw container still runs as non-root UID/GID `1000`.

Final file permissions stay intentionally strict for OpenSSH compatibility:

- `/home/node/.ssh` is created with mode `0700`;
- `id_ed25519` is written with mode `0600`;
- `known_hosts` is left readable with mode `0644`.

If the Secret is missing either key or either file is empty, or if the init container cannot finish the permission-lockdown and ownership handoff steps, OpenClaw will stay in `Init:CrashLoopBackOff`; inspect the `remote-docker-ssh-permissions` init-container logs first because they print the exact `remoteDocker.ssh.secretName` requirement and missing key names.

Troubleshooting note: when OpenClaw is stuck in init, inspect the previous init-container attempt with `kubectl logs <pod> -c remote-docker-ssh-permissions --previous` to see whether the SSH copy, permission-lockdown, or ownership-handoff step failed.

## Example: secrets + values (`existingSecret` / `secretRefs` style)

Example Secret (operator-managed):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: openclaw-secrets
type: Opaque
stringData:
  OPENCLAW_GATEWAY_TOKEN: "replace-with-long-random-token"
  OPENAI_API_KEY: "replace-with-openai-key"
  ANTHROPIC_API_KEY: "replace-with-anthropic-key"
  GEMINI_API_KEY: "replace-with-gemini-key"

  BRAVE_API_KEY: "optional"
  PERPLEXITY_API_KEY: "optional"
  XAI_API_KEY: "optional"
  MOONSHOT_API_KEY: "optional"
```

Example values override:

```yaml
existingSecret: openclaw-secrets
secretKeys:
  gatewayToken: OPENCLAW_GATEWAY_TOKEN
  openaiApiKey: OPENAI_API_KEY
  anthropicApiKey: ANTHROPIC_API_KEY
  braveApiKey: BRAVE_API_KEY
  perplexityApiKey: PERPLEXITY_API_KEY
  geminiApiKey: GEMINI_API_KEY
  xaiApiKey: XAI_API_KEY
  moonshotApiKey: MOONSHOT_API_KEY

ingress:
  enabled: true
  hosts:
    - host: openclaw.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: openclaw-tls
      hosts:
        - openclaw.example.com

openclaw:
  gateway:
    bind: lan
    auth:
      mode: token
    controlUi:
      allowedOrigins:
        - https://openclaw.example.com
```

Example environment-specific remote-Docker override snippet:

```yaml
image:
  repository: <registry>/openclaw-remote-docker
  tag: <image-tag>

remoteDocker:
  dockerHost: ssh://docker-remote@<remote-docker-host>:2222
  home: /home/node
  ssh:
    secretName: openclaw-remote-docker-ssh
    mountPath: /home/node/.ssh

openclaw:
  agents:
    defaults:
      sandbox:
        docker:
          image: registry.example.com/coder/openclaw-sandbox:trixie-slim
        browser:
          image: openclaw-sandbox-browser:bookworm-slim
          cdpSourceRange: 10.42.0.0/16
```
