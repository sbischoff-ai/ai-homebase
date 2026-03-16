# OpenClaw chart notes

This chart deploys OpenClaw as a **single trusted-boundary, long-running gateway host** with durable state and private-by-default browser access.

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
- `Ingress` is disabled by default (`ingress.enabled: false`) to keep exposure private/internal unless explicitly enabled.

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
- `ingress.enabled` is `false` by default.
- Access should come through private networking such as VPN, for example: `http://openclaw.default.svc.cluster.local:18789`.

## Ingress and origin requirements

If you intentionally enable browser ingress, set all of the following:

1. Ingress hostname (`ingress.hosts[*].host`, `ingress.defaultHost`, or `global.hosts.openclaw`).
2. TLS for that hostname (`ingress.tls`).
3. `openclaw.gateway.controlUi.allowedOrigins` to exact public origin(s), for example:
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
