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

For `wg-easy`, when `existingSecret` is set in your overlay, that Secret must include both `WG_HOST` and `PASSWORD_HASH` keys.

### Registry/image prerequisites

- Image repositories and tags/digests updated to your ACR paths.
- Pull auth configured (`global.imagePullSecrets`) if needed.

## 2) Service toggle planning

In your overlay, explicitly decide enabled state for optional services:

- `nextcloud.enabled`
- `gitea.enabled`
- `paperlessNgx.enabled`

Core access services should remain enabled:

- `infisical.enabled`
- `wgEasy.enabled`

Recommendation: keep `wgEasy.enabled: true` for AKS environments because it is the expected access plane for internal services; enable optional services only when required to reduce attack surface and ops overhead.

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
- AKS baseline keeps wg-easy UI ingress disabled (`wgEasy.ingress.enabled: false`) and `wgEasy.service.type: ClusterIP`.
- Publish the WireGuard UDP endpoint explicitly via a dedicated overlay (example: `examples/aks.wg-easy-udp-lb.override.yaml`) that sets `wgEasy.service.type: LoadBalancer` and constrains `wgEasy.service.loadBalancerSourceRanges`.

### AKS pre-flight check: wg-easy UDP reachability

Before rollout, verify expected VPN reachability and exposure intent:

1. Confirm the effective values keep wg-easy enabled and web UI ingress private unless intentionally overridden.
2. If using UDP exposure overlay, verify the expected LB settings render (`type: LoadBalancer`, UDP port `51820`, and intended source CIDR allow-list).
3. Validate that `WG_HOST` in the runtime secret matches the reachable VPN endpoint/FQDN you plan to publish.
4. Confirm network controls (NSG/firewall and any cluster policy) allow inbound UDP/51820 from the approved source ranges only.
5. On every target node pool that may run wg-easy, verify legacy xtables NAT support exists before rollout: required modules (`wireguard`, `ip_tables`, `iptable_nat`; usually `iptable_filter`) and `iptables -t nat -L` succeeds.
6. If a node pool is nftables-only / legacy-xtables-disabled, constrain scheduling so wg-easy runs only on compatible nodes (or use a different VPN/NAT pattern).

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

- Correct ingress host/class/TLS blocks (for OpenHands: `openhands.ingress.hostName`, `openhands.ingress.ingressClassName`, `openhands.ingress.tls`).
- Enabled/disabled services matching plan.
- PVC class/size values matching storage design.
- Secret references pointing to existing target Secret names.

## 7) Install/upgrade

Preferred helper script:

```bash
./scripts/install.sh --profile aks \
  --values-file charts/platform-stack/values-aks.yaml \
  --values-file values-aks.<env>.yaml
```

Equivalent raw Helm command:

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
