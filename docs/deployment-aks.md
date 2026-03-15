# AKS deployment flow

This guide describes an AKS-first rollout of `platform-stack` including service toggles, storage classes, ingress, and secret prerequisites.

## 0) Scope and assumptions

- You are deploying `charts/platform-stack`.
- You will start from `charts/platform-stack/values-aks.yaml` and add an environment-specific override file.
- Optional services are enabled intentionally; core services are always evaluated first.

> **Intentional placeholders:** values in `values-aks.yaml` include example hostnames, client IDs, and secret mappings that must be replaced before production use.

## 1) Prerequisites

### AKS and cluster access

- AKS cluster exists and is reachable with `kubectl`.
- Namespace chosen (examples use `ai-homebase`).
- Helm v3 and kubectl installed.

### Ingress/TLS prerequisites

- Ingress controller installed (typically NGINX class `nginx`).
- TLS issuer available (for example cert-manager `ClusterIssuer`).
- DNS records planned for enabled public hosts.

### Secret prerequisites

At least one secret strategy must be ready before install:

1. **Pre-created Kubernetes Secrets** referenced by `existingSecret`/`secretRefs`.
2. **External Secrets workflow** with valid `secretStoreRef` and mappings.

### Registry/image prerequisites

- Image repositories and tags/digests updated to your ACR paths.
- Pull auth configured (`global.imagePullSecrets`) if needed.

## 2) Service toggle planning

In your overlay, explicitly decide enabled state for optional services:

- `nextcloud.enabled`
- `gitea.enabled`
- `paperlessNgx.enabled`
- `infisical.enabled`
- `wgEasy.enabled`

Recommendation: enable only required services per environment to reduce attack surface and ops overhead.

## 3) Storage-class and PVC planning

`platform-stack` resolves `storageClassName` via service override -> global fallback -> cluster default.

AKS guidance:

- Set `global.storageClass` only if one class should be shared broadly.
- Override per service when profile differs (for example premium disk for latency-sensitive paths).
- Validate expansion/snapshot support for every class in use.
- Pre-size PVCs for growth-heavy services (Nextcloud, Paperless media, execution workspaces).

## 4) Ingress and network exposure planning

Per-service ingress is controlled independently:

- `openclaw.ingress.*` (kept disabled in AKS baseline; enable explicitly if your environment requires ingress)
- `openhands.ingress.*` (kept disabled in AKS baseline; enable only when an environment overlay explicitly requires direct UI/API exposure)
- Optional service ingress blocks (`nextcloud`, `gitea`, `paperlessNgx`, `infisical`, `wgEasy`)

AKS notes:

- `openhands.service.type=ClusterIP` remains valid; if you enable ingress in an environment overlay, that ingress can provide external UI/API exposure.
- Use internal ingress patterns instead of public exposure for admin/internal tools.
- For wg-easy, prefer private web UI + controlled UDP VPN exposure.

## 5) Prepare values files

Use two layers minimum:

1. `charts/platform-stack/values-aks.yaml` (baseline).
2. `values-aks.<env>.yaml` (real hostnames, secrets, class overrides, toggles).

Avoid editing `values-aks.yaml` directly for environment-specific secrets or hostnames.

## 6) Validate before apply

```bash
helm dependency update charts/platform-stack
helm lint charts/platform-stack -f charts/platform-stack/values-aks.yaml -f values-aks.<env>.yaml
helm template platform-stack charts/platform-stack \
  -n ai-homebase \
  -f charts/platform-stack/values-aks.yaml \
  -f values-aks.<env>.yaml
```

Check for:

- Correct ingress hosts/class/TLS blocks.
- Enabled/disabled services matching plan.
- PVC class/size values matching storage design.
- Secret references pointing to existing target Secret names.

## 7) Install/upgrade

```bash
helm upgrade --install platform-stack charts/platform-stack \
  -n ai-homebase \
  --create-namespace \
  -f charts/platform-stack/values-aks.yaml \
  -f values-aks.<env>.yaml
```

## 8) Post-deploy verification

- Pods running for core plane first (`openclaw`, `openhands`).
- Optional services present only when enabled.
- PVCs bound with expected storage classes.
- Ingress objects provisioned with expected hosts/TLS.
- Secret-backed env vars resolved (no crash loops from missing keys).

## Production-hardening gaps checklist

Before production promotion, confirm:

- Placeholder domains/annotations/client IDs are fully replaced.
- NetworkPolicies enforce least privilege (not just defaults).
- Backup/restore tested for all persistent services.
- Pod security context and runtime isolation tuned for OpenHands workers.
- Monitoring/alerts wired to real destinations.
