# OpenClaw chart notes

This chart deploys OpenClaw as a **single trusted-boundary, long-running gateway host** with durable state and the repo's standard ingress-on access model.

## What this chart configures by default

- **One replica** (`replicaCount: 1`) because the gateway owns mutable state.
- **Durable state** (`persistence.enabled: true`) mounted at `/home/node/.openclaw` and exported as `OPENCLAW_STATE_DIR`.
- For the supported remote-Docker posture, the `k3d` and `k3s` overlays switch that durable state to a shared `hostPath` so the gateway pod and the sandbox host see the same `/home/node/.openclaw` tree. OpenClaw binds sandbox workspaces from that state directory; if the two environments do not share it, sandboxed agents will see empty `/workspace` mounts.
- The coder sandbox contract separates working tree from tool state: `/workspace` is the bound repo workdir, while `/workspace/.home` is the durable writable home used for `HOME`, `CODEX_HOME`, and XDG state. That keeps Codex CLI and other developer tooling writable without assuming the workspace root itself is the shell home.
- **Writable runtime tempdir** mounted at `/tmp` via `emptyDir` (`medium: Memory`) so non-root UID `1000` can always create OpenClaw startup temp paths (for example `/tmp/openclaw-1000`) even when the root filesystem is read-only.
- A rendered `openclaw.json` from chart values, used only to bootstrap the persistent config file at `/home/node/.openclaw/openclaw.json` on first start. After that, UI-driven settings changes stay on the PVC across pod restarts and redeploys instead of being overwritten from the ConfigMap. The shipped main workspace path is the absolute `/home/node/.openclaw/workspace` to stay inside the PVC without duplicating `.openclaw` in the resolved path, and additional agents use sibling paths such as `/home/node/.openclaw/workspace-architect`, `/home/node/.openclaw/workspace-coder`, and `/home/node/.openclaw/workspace-watchdog`.
- A rendered `openclaw.cron` scheduler block in `openclaw.json` so the persistent gateway config carries the documented cron store and retention settings. Repo-managed recurring jobs are seeded separately after startup through the OpenClaw CLI rather than embedded directly in the config file.
- A first-run workspace seeding step that creates role files inside each agent workspace when they are missing. `main` gets a seeded `BOOTSTRAP.md` plus the durable role files so the normal first-use ritual still has an entrypoint, while `architect`, `coder`, and `watchdog` start as ready specialists.
- The container explicitly starts the gateway in the foreground (`node openclaw.mjs gateway --allow-unconfigured`) to avoid container runtime startup flows that assume a user-level service manager (for example `systemctl --user`).
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
- At least one model provider key for assistant responses, for example `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `XAI_API_KEY`, or `MOONSHOT_API_KEY`.

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

The chart renders `commands.*`, `tools.*`, `agents.defaults.*`, `agents.list[]`, `skills.*`, `mcp.*`, and `plugins.*` into `openclaw.json`. The shipped defaults set up Docker sandboxing with explicit `backend: "docker"` plus `docker.*` and `browser.*` fields, bootstrap `main`, `architect`, `coder`, and `watchdog` agents, enable `tools.agentToAgent` with `tools.sessions.visibility=all`, and force `plugins.slots.memory = "none"` so builtin OpenClaw memory tools stay disabled. `main` is the user-facing project manager and generalist for ordinary non-coding tasks, but it should not create project folders, write specs, or do durable task decomposition. That work belongs with `architect`, which treats projects as durable units with curated `/Projects/<slug>/` artifacts and temporary `/Notes/<slug>/` working material in Nextcloud. `coder` overrides the default sandbox image so it can execute repo and GitOps work with common developer tooling installed, plus Codex CLI for delegated implementation work; the regular and coder sandbox images now default to canonical in-cluster registry refs rather than local tags, and coder guidance assumes separate GitOps and sandbox-images repos in Gitea. GitHub access is optional and additive, while Gitea remains the default internal workflow. `watchdog` overrides sandboxing to `off` so it always runs in the gateway for low-cost heartbeat work. Because MCP-injected tools are not reliably hidden by per-agent deny rules, and because this stack standardizes on Qdrant for cross-agent recall, the chart now relies on the shared Qdrant MCP surface plus seeded workspace instructions instead of OpenClaw's builtin memory plugin. The chart also includes a local `node` launcher that bridges stdio MCP traffic to a remote HTTP MCP endpoint at `/opt/openclaw-runtime/mcp/mcp-http-bridge.mjs`, and keeps `remoteDocker.enabled=true` so the Deployment exports `DOCKER_HOST`/`HOME`, prepares an SSH directory at `remoteDocker.ssh.mountPath`, and mounts the referenced Secret for the standard remote Docker path.

Remote Docker mode now installs the Docker CLI into the pod via the `remoteDocker.cli.*` init-container flow. The main OpenClaw image still needs an SSH client because Docker's `ssh://` transport shells out to `ssh`.

If the OpenClaw image does not include `ssh`, the Deployment now fails early in init with an explicit error instead of starting a pod that cannot reach the remote Docker daemon.

This repo includes a repo-managed gateway Dockerfile at `images/openclaw-remote-docker/Dockerfile` that rebases the OpenClaw runtime onto a newer Debian userland so `mgconsole` works natively, while still carrying `docker.io`, `openssh-client`, `jq`, and `ripgrep` for the supported watchdog/session-logs posture. It also ships `images/openclaw-sandbox-base/Dockerfile`, which uses the same newer glibc baseline and carries `jq`, `ripgrep`, and `mgconsole` for the regular sandbox image, plus `images/openclaw-sandbox-coder/Dockerfile`, a coder-specific sandbox image layered on top of that base. The Deployment also seeds a compatible `mgconsole` wrapper plus runtime libraries into the gateway pod at `/opt/memgraph-tools` so Memgraph access stays available even when the upstream OpenClaw image is still in use. Any sandbox image used for remote agent execution should expose the same shared MCP bridge path `/opt/openclaw-runtime/mcp/mcp-http-bridge.mjs` if you want MCP bridges to work inside sandboxed agents too.

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
  # or use ANTHROPIC_API_KEY instead of OPENAI_API_KEY

  BRAVE_API_KEY: "optional"
  PERPLEXITY_API_KEY: "optional"
  GEMINI_API_KEY: "optional"
  XAI_API_KEY: "optional"
  MOONSHOT_API_KEY: "optional"
```

Example values override:

```yaml
existingSecret: openclaw-secrets
secretKeys:
  gatewayToken: OPENCLAW_GATEWAY_TOKEN
  openaiApiKey: OPENAI_API_KEY
  # anthropicApiKey: ANTHROPIC_API_KEY
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
