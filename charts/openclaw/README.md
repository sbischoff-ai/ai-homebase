# OpenClaw chart notes

This chart deploys OpenClaw as a **single trusted-boundary, long-running gateway host** with durable state and the repo's standard ingress-on access model.

## What this chart configures by default

- **One replica** (`replicaCount: 1`) because the gateway owns mutable state.
- **Durable state** (`persistence.enabled: true`) mounted at `/home/node/.openclaw` and exported as `OPENCLAW_STATE_DIR`.
- **Writable runtime tempdir** mounted at `/tmp` via `emptyDir` (`medium: Memory`) so non-root UID `1000` can always create OpenClaw startup temp paths (for example `/tmp/openclaw-1000`) even when the root filesystem is read-only.
- A rendered `openclaw.json` from chart values, mounted read-only and set via `OPENCLAW_CONFIG_PATH=/etc/openclaw/openclaw.json`.
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
- At least one model provider key for assistant responses:
  - `OPENAI_API_KEY`, or
  - `ANTHROPIC_API_KEY`.

Without a model provider key, the UI can load but the assistant will not produce responses.

If `openclaw.gateway.auth.mode=token`, Helm rendering fails unless `existingSecret` and `secretKeys.gatewayToken` are configured.

## Optional provider/search/tooling keys

Optional keys for additional providers and web-search tooling:

- `BRAVE_API_KEY`
- `PERPLEXITY_API_KEY`
- `GEMINI_API_KEY`
- `XAI_API_KEY`
- `KIMI_API_KEY` / `MOONSHOT_API_KEY`
- `TAVILY_API_KEY`

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

For non-loopback binds, wildcard origins are intentionally rejected.

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

The chart renders `agents.defaults.sandbox.*` plus `plugins.*` into `openclaw.json`. The shipped defaults set up Docker sandboxing with explicit `docker.*` and `browser.*` fields, including `browser.cdpSourceRange` for remote browser access control, and keep `remoteDocker.enabled=true` so the Deployment exports `DOCKER_HOST`/`HOME`, prepares an SSH directory at `remoteDocker.ssh.mountPath`, and mounts the referenced Secret for the standard remote Docker path while OpenClaw still uses the `docker` backend.

Remote Docker mode assumes the OpenClaw container image already includes both:

- Docker CLI
- OpenSSH client

This repo includes an example Dockerfile at `images/openclaw-remote-docker/Dockerfile` that extends `ghcr.io/openclaw/openclaw:2026.3.13-1` with those packages.

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
  KIMI_API_KEY: "optional"
  MOONSHOT_API_KEY: "optional"
  TAVILY_API_KEY: "optional"
```

Example values override:

```yaml
existingSecret: openclaw-secrets
secretKeys:
  gatewayToken: OPENCLAW_GATEWAY_TOKEN
  openaiApiKey: OPENAI_API_KEY
  # anthropicApiKey: ANTHROPIC_API_KEY
  braveApiKey: BRAVE_API_KEY
  tavilyApiKey: TAVILY_API_KEY
  perplexityApiKey: PERPLEXITY_API_KEY
  geminiApiKey: GEMINI_API_KEY
  xaiApiKey: XAI_API_KEY
  kimiApiKey: KIMI_API_KEY
  moonshotApiKey: MOONSHOT_API_KEY

secretRefs:
  - name: openclaw-secrets
    key: TAVILY_API_KEY
    envVar: TAVILY_API_KEY

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
          image: openclaw-sandbox:bookworm-slim
        browser:
          image: openclaw-sandbox-browser:bookworm-slim
          cdpSourceRange: 10.42.0.0/16
```
