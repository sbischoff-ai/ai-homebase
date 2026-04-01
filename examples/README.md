# Examples

All examples in this directory use placeholders only. Replace values like `<your-namespace>`, `<your-release>`, and `<your-kube-context>` before running commands.

For normal bootstrap flows, prefer `bootstrap.example.toml` + `bootstrap.local.toml` together with `scripts/bootstrap-stack.sh --profile <k3d|k3s> --bootstrap-config ...`. For migrated application secrets, prefer the SOPS workflow in [`docs/secrets.md`](../docs/secrets.md). The manual `kubectl create secret` examples below remain useful for debugging or custom secret-management workflows.

## Dummy secrets for all components

```bash
kubectl --context <your-kube-context> -n <your-namespace> create secret generic openclaw-secrets   --from-literal=OPENCLAW_GATEWAY_TOKEN=<dummy-openclaw-gateway-token>

kubectl --context <your-kube-context> -n <your-namespace> create secret generic openclaw-remote-docker-ssh   --from-file=id_ed25519=<path-to-private-key>   --from-file=known_hosts=<path-to-known-hosts>

kubectl --context <your-kube-context> -n <your-namespace> create secret generic vaultwarden-config-secrets   --from-literal=DATABASE_URL=postgresql://vaultwarden:<db-password>@platform-stack-shared-postgresql:5432/vaultwarden

kubectl --context <your-kube-context> -n <your-namespace> create secret generic nextcloud-config-secrets   --from-literal=NEXTCLOUD_ADMIN_PASSWORD=<nextcloud-admin-password>   --from-literal=POSTGRES_PASSWORD=<nextcloud-db-password>   --from-literal=REDIS_HOST_PASSWORD=<shared-redis-password>
```

`openclaw-remote-docker-ssh` is part of the standard OpenClaw deployment posture in this repo; every supported target needs an equivalent Secret even if you override the name in values. The chart requires the Secret referenced by `remoteDocker.ssh.secretName` to provide exactly two SSH data keys: non-empty `id_ed25519` and non-empty `known_hosts`.

If an OpenClaw pod stalls in `Init:CrashLoopBackOff`, inspect the `remote-docker-ssh-permissions` init-container logs first to confirm those exact keys exist in the Secret and contain data.

## Example overlay guide

These example files are layer-on-top overlays, not standalone configs: apply them only after `charts/platform-stack/values.yaml` and the appropriate supported target overlay for your environment.

- `examples/k3d.values.override.yaml`: Use this as an optional layer-on-top overlay after `values-k3d.yaml` when you need local `k3d`-specific hostnames, image, ingress, storage, or temporary service adjustments on top of the shipped local Nextcloud/Gitea/Vaultwarden/OpenClaw stack.
- `examples/k3s.values.override.yaml`: Use this as an optional layer-on-top overlay after `values-k3s.yaml` when you need homelab `k3s` hostnames, registry settings, or other environment-specific production overrides.
- `examples/profile-core-only.override.yaml`: Use this as a layer-on-top profile overlay when you want only the core OpenClaw service enabled on top of an existing target stack.
- `examples/profile-content-services.override.yaml`: Use this as a layer-on-top profile overlay when you want to enable the optional content, password-management, and collaboration services on top of an existing target stack.
- `examples/openclaw.remote-docker.values.yaml`: Use this as a layer-on-top overlay when a concrete environment needs to override the standard OpenClaw remote Docker endpoint, SSH Secret, or sandbox image settings.

## k3d local override layering

Order:

1. `charts/platform-stack/values.yaml`
2. `charts/platform-stack/values-k3d.yaml`
3. `examples/k3d.values.override.yaml` (optional)

```bash
./scripts/template.sh   --release-name <your-release>   --namespace <your-namespace>   --kube-context <your-kube-context>   --values-file charts/platform-stack/values.yaml   --values-file charts/platform-stack/values-k3d.yaml   --values-file examples/k3d.values.override.yaml
```

## k3s homelab override layering

Order:

1. `charts/platform-stack/values.yaml`
2. `charts/platform-stack/values-k3s.yaml`
3. `examples/k3s.values.override.yaml` (optional)

```bash
./scripts/template.sh   --release-name <your-release>   --namespace <your-namespace>   --kube-context <your-kube-context>   --values-file charts/platform-stack/values.yaml   --values-file charts/platform-stack/values-k3s.yaml   --values-file examples/k3s.values.override.yaml
```

## Remote Docker overlay

`examples/openclaw.remote-docker.values.yaml` shows the environment-specific values you may still need to adjust on top of the standard remote-Docker posture to:

- switch OpenClaw to an image that contains Docker CLI + OpenSSH client,
- change `DOCKER_HOST` when your Incus VM is not reachable at the shipped target default,
- change the SSH Secret name or mount path, and
- set the remote browser sandbox image names plus `browser.cdpSourceRange`.

Example layering:

```bash
./scripts/template.sh   --release-name <your-release>   --namespace <your-namespace>   --kube-context <your-kube-context>   --values-file charts/platform-stack/values.yaml   --values-file charts/platform-stack/values-k3d.yaml   --values-file examples/openclaw.remote-docker.values.yaml
```
