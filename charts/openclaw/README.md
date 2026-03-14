# OpenClaw chart notes

This chart deploys OpenClaw with token-gated gateway auth enabled by default.

## Required operator-provided secrets

You must provide a Kubernetes Secret that includes:

- `OPENCLAW_GATEWAY_TOKEN` (**mandatory**) for gateway authentication.
- At least one model provider key for assistant responses:
  - `OPENAI_API_KEY`, or
  - `ANTHROPIC_API_KEY`.

If `openclaw.gateway.auth.mode=token`, Helm rendering fails unless `existingSecret` and `secretKeys.gatewayToken` are configured.

## Optional provider/search/tooling keys

You can also provide optional keys for extra providers and tools:

- `BRAVE_API_KEY`
- `PERPLEXITY_API_KEY`
- `GEMINI_API_KEY`
- `XAI_API_KEY`
- `KIMI_API_KEY` / `MOONSHOT_API_KEY`
- `TAVILY_API_KEY`

Use `secretRefs` to map these keys directly into the OpenClaw container environment with exact variable names.

## Ingress and origin requirements

For external access:

1. Set an ingress host.
2. Configure TLS for that host.
3. Set `openclaw.gateway.controlUi.allowedOrigins` to the exact public origin (scheme + host), for example:
   - `https://openclaw.example.com`

`allowedOrigins` should match how users actually reach the service (no wildcard for internet exposure).

## First-use auth and pairing behavior

- OpenClaw uses **token auth on the WebSocket handshake** (gateway token).
- On first connection from a new device/client, you may see a one-time pairing request that requires approval.
- Operational approval path:

```bash
openclaw devices list
openclaw devices approve <requestId>
```

## Trust model

This deployment model is suitable for a **single trusted operator or household boundary**.
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

secretRefs:
  - name: openclaw-secrets
    key: BRAVE_API_KEY
    envVar: BRAVE_API_KEY
  - name: openclaw-secrets
    key: PERPLEXITY_API_KEY
    envVar: PERPLEXITY_API_KEY
  - name: openclaw-secrets
    key: GEMINI_API_KEY
    envVar: GEMINI_API_KEY
  - name: openclaw-secrets
    key: XAI_API_KEY
    envVar: XAI_API_KEY
  - name: openclaw-secrets
    key: KIMI_API_KEY
    envVar: KIMI_API_KEY
  - name: openclaw-secrets
    key: MOONSHOT_API_KEY
    envVar: MOONSHOT_API_KEY
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
