# OpenHands chart notes

This chart deploys OpenHands with a private-by-default posture aligned to this repo's internal-service conventions.

## Default access posture

- `service.type: ClusterIP`
- `ingress.enabled: false`
- No public ingress is created unless you explicitly opt in.

Expected access path is through existing private connectivity (WireGuard/VPN) and internal DNS, for example `http://openhands.default.svc.cluster.local:3000` or your internal ingress hostname.

Security/runtime defaults run as root (`runAsUser: 0`, `runAsGroup: 0`, `podSecurityContext.fsGroup: 0`, `runAsNonRoot: false`) because the upstream image currently requires `/app/entrypoint.sh` to start as root. Avoid mounting any extra operator-defined volume at `/app` (or `/app/*`) because it shadows the baked-in `/app/entrypoint.sh` and prevents container startup; the chart-managed single-file `/app/config.toml` subPath mount is the intentional exception used to render the OpenHands runtime configuration.

## Kubernetes runtime sandboxing

This chart now renders the upstream OpenHands Kubernetes runtime configuration directly into `config.toml`:

```yaml
runtime:
  mode: kubernetes
kubernetes:
  namespace: ai-homebase
  ingress_domain: openhands.homebase.local
  pvc_storage_size: 2Gi
  pvc_storage_class: local-path
  resource_cpu_request: "1"
  resource_memory_request: 1Gi
  resource_memory_limit: 2Gi
  image_pull_secret: ""
  ingress_tls_secret: ""
  node_selector_key: ""
  node_selector_val: ""
  tolerations_yaml: ""
  privileged: false
```

The OpenHands pod stays lightweight and uses namespace-scoped RBAC to create per-session runtime pods, services, ingresses, and PVCs inside the cluster. This runtime currently assumes OpenHands itself is running in-cluster.

## Secret inputs

Provide app credentials using `existingSecret`, `secretRefs`, and/or `secretEnv`.

Required:

- `LLM_API_KEY`

Common optional keys:

- `LLM_MODEL`
- `OH_WEB_URL`
- Provider or SCM credentials as needed by your workflows (for example `OPENAI_API_KEY`, `GITHUB_TOKEN`)

## Minimal values overrides

### 1) Existing secret reference

```yaml
existingSecret: openhands-app-secrets

secretRefs:
  - name: openhands-app-secrets
    key: LLM_API_KEY
    envVar: LLM_API_KEY
  - name: openhands-app-secrets
    key: LLM_MODEL
    envVar: LLM_MODEL
  - name: openhands-app-secrets
    key: OH_WEB_URL
    envVar: OH_WEB_URL
```

### 2) OpenHands control-plane persistence size / storage class

```yaml
persistence:
  enabled: true
  size: 50Gi
  storageClass: local-path
```

### 3) Optional internal ingress enablement

```yaml
ingress:
  enabled: true
  ingressClassName: nginx-internal
  hostName: openhands.internal.home.arpa
  tls:
    - secretName: openhands-internal-tls
      hosts:
        - openhands.internal.home.arpa
```

Keep ingress internal unless you have a deliberate public-exposure design (auth, TLS, and network controls) in place.


Ingress class precedence:

- Prefer `ingress.ingressClassName` on modern Kubernetes.
- `ingress.annotations["kubernetes.io/ingress.class"]` is treated as a legacy fallback and is only applied when `ingress.ingressClassName` is empty.
- Do not set both fields at the same time; when both are present, the chart removes the legacy annotation from the rendered Ingress to avoid conflicting class mechanisms.
