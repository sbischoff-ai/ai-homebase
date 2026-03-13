# AKS deployment guide

This document describes a practical bootstrap flow for running `platform-stack` on Azure Kubernetes Service (AKS) using the AKS profile at `charts/platform-stack/values-aks.yaml`.

For placeholder-only command examples and override files that match chart value keys, see [`examples/README.md`](../examples/README.md).

## Prerequisites

Before deployment, ensure you have:

- Azure subscription and permissions to create/update AKS and ACR resources.
- AKS cluster with:
  - OIDC issuer enabled.
  - Workload identity enabled (if using Key Vault, Service Bus, or other Azure identity-based access).
- ACR registry with push/pull access for your build agents and cluster identity.
- Ingress controller installed (assumes NGINX ingress in this profile).
- Optional but common integrations:
  - cert-manager for TLS certificate automation.
  - external-dns for hostname automation.
  - External Secrets Operator if syncing secrets from Key Vault.

CLI tooling:

- `az`, `kubectl`, `helm`.

## Namespace and bootstrap flow

Recommended order:

1. **Create namespace** (example: `ai-homebase`).
2. **Create image pull secret** if not using managed identity-based ACR pull.
3. **Install/verify cluster addons** (ingress, cert-manager, external-dns, ESO).
4. **Prepare workload identity bindings** for each service account used by `openclaw` and `openhands`.
5. **Configure secret stores** (for example, `ClusterSecretStore` for Key Vault).
6. **Deploy chart dependencies** and render manifests for validation.
7. **Install/upgrade `platform-stack`** with `values-aks.yaml` plus your environment override.

Example skeleton commands:

```bash
kubectl create namespace ai-homebase
helm dependency update charts/platform-stack
helm template platform-stack charts/platform-stack \
  -n ai-homebase \
  -f charts/platform-stack/values-aks.yaml
helm upgrade --install platform-stack charts/platform-stack \
  -n ai-homebase \
  -f charts/platform-stack/values-aks.yaml
```

## ACR image notes

`values-aks.yaml` intentionally uses ACR-style repositories:

- `myregistry.azurecr.io/openclaw`
- `myregistry.azurecr.io/openhands`

Update these for your registry and promote immutable tags (or digests) per environment. Avoid relying on mutable tags alone for production rollouts.

If you keep `global.imagePullSecrets` (example `acr-pull`), ensure that secret exists in the target namespace.

## Workload identity notes

The AKS profile includes service account annotation placeholders:

- `azure.workload.identity/client-id: "<openclaw-workload-identity-client-id>"`
- `azure.workload.identity/client-id: "<openhands-workload-identity-client-id>"`

Replace placeholders with managed identity client IDs and bind federated credentials to the corresponding Kubernetes service accounts.

Typical split:

- `openclaw`: read app/platform secrets and potentially write control-plane metadata.
- `openhands`: read runtime secrets and access execution dependencies (queue/storage/artifacts).

Grant least privilege per identity rather than sharing one broad identity across both services.

## Ingress assumptions

AKS values assume:

- NGINX ingress class (`className: nginx`).
- Public hostname for `openclaw`.
- TLS managed by cert-manager (`cert-manager.io/cluster-issuer` annotation examples).
- Optional external-dns annotation for automatic DNS registration.

`openhands` remains internal by default and should not be exposed publicly unless your threat model explicitly allows it.

## Storage guidance

The AKS profile defaults to `managed-csi` and enables persistence for both components.

Guidance:

- Use separate PVC sizing strategies:
  - `openclaw`: smaller durable state.
  - `openhands`: larger, execution-workspace-oriented storage.
- Align storage classes with workload patterns (latency vs throughput vs cost).
- Keep backup/snapshot policy aligned to data criticality:
  - Control-plane metadata usually needs stricter retention.
  - Execution workspace data may be more ephemeral.

For production, validate backup, restore, and snapshot procedures before go-live.
