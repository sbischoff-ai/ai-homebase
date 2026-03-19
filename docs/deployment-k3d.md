# k3d local deployment flow

This guide describes the local `k3d` workflow for `platform-stack`, including cluster bootstrap, deploy/smoke checks, ingress host access, and common troubleshooting.

## 0) Prerequisites

Install and verify:

- [k3d](https://k3d.io/)
- [Docker](https://docs.docker.com/get-docker/)
- [Incus](https://linuxcontainers.org/incus/) installed on the host, with an initialized local daemon, a bridge network (the bootstrap assumes `incusbr0` by default), and storage/profile defaults that can boot a VM
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm 3](https://helm.sh/docs/intro/install/)

## 1) Recommended bootstrap

```bash
export OPENAI_API_KEY="<your-openai-api-key>"
./scripts/k3d-local-bootstrap.sh --cluster-name ai-homebase-dev
```

This flow:

- creates or reuses the k3d cluster,
- creates or reuses a dedicated Incus VM for remote Docker sandboxing,
- installs ingress-nginx,
- generates bootstrap secrets,
- deploys `platform-stack` with `values.yaml + values-k3d.yaml`, and
- runs local smoke checks.

The bootstrap exports `KUBECONFIG` to the dedicated kubeconfig path for the lifetime of the script so nested `kubectl` and `helm` calls all target the same local cluster.
The companion Incus VM is intentionally minimal: `images:debian/12/cloud`, **2 vCPU**, **6 GiB RAM**, a 12 GiB root disk, Docker Engine, and SSH. On the first boot, cloud-init still needs time to install Docker Engine and SSH packages, so VM readiness may take several minutes before the SSH endpoint comes up. `scripts/incus-vm-up.sh` now uses a 600-second readiness deadline by default, and you can raise or lower it with `SSH_READY_TIMEOUT_SECONDS` or `--ssh-ready-timeout-seconds` when needed. If `cloud-init status` reports a terminal guest failure such as `status: error`, the helper now stops immediately instead of continuing to wait on SSH, then records the failure reason together with `cloud-init status --long`, `journalctl -u cloud-init --no-pager`, and `incus console --show-log` output. The bootstrap now applies the root disk size as an instance-level device override so it works even when the `default` Incus profile provides the root disk device. Instead of exposing the Docker daemon over unauthenticated TCP, the bootstrap configures SSH access, creates the `openclaw-remote-docker-ssh` Secret, programs the Incus VM proxy in **NAT mode** with a stable VM IPv4 on `incusbr0`, and handles the instance-specific guest networking itself by deriving the bridge gateway from `incus network get <bridge> ipv4.address` and rendering an explicit NoCloud `network-config` with the guest static IPv4, a cloud-init/netplan-compatible default route (`to: 0.0.0.0/0`), and DNS resolvers before `package_update` runs. The resolved host-side listen address and Docker endpoint are written to `~/.local/state/ai-homebase/incus/<vm-name>.env`, and the local bootstrap layers a temporary Helm values override so OpenClaw uses that exact endpoint. If Incus does not populate runtime `state.network.addresses`, the helper now still succeeds once the guest boots and the configured host-side SSH endpoint becomes reachable, using the configured static IPv4 as the guest address of record.

## 2) Manual flow

### 2.1 Bootstrap the local cluster

```bash
./scripts/k3d-up.sh --cluster-name ai-homebase-dev
./scripts/incus-vm-up.sh --vm-name openclaw-sandbox
source ~/.local/state/ai-homebase/incus/openclaw-sandbox.env
```

`k3d-up.sh` disables the bundled k3s Traefik deployment so `ingress-nginx` remains the only intended HTTP/HTTPS ingress controller in the local cluster. k3d itself still runs on Docker to host the local cluster.
Expect the Incus helper to spend a few minutes on the very first run while cloud-init installs Docker Engine and SSH; it now seeds both NoCloud user-data and an instance-specific NoCloud `network-config` before boot so package installation does not depend on implicit bridge/cloud-image networking or DHCP defaults inside the guest. If your machine is slower than the default 600-second wait, pass `--ssh-ready-timeout-seconds <seconds>` or export `SSH_READY_TIMEOUT_SECONDS`.

### 2.2 Generate bootstrap secrets

```bash
export OPENAI_API_KEY="<your-openai-api-key>"
./scripts/k3d-bootstrap-secrets.sh \
  --namespace ai-homebase \
  --release-name platform-stack \
  --kubeconfig ~/.kube/k3d-ai-homebase-dev.yaml \
  --remote-docker-host "$HOST_LISTEN_ADDRESS" \
  --remote-docker-port "$SSH_HOST_PORT" \
  --remote-docker-key ~/.local/state/ai-homebase/incus/openclaw-sandbox-id_ed25519
```

For the OpenClaw deployment itself, layer a one-off override that matches the same endpoint:

```bash
cat >/tmp/platform-stack-k3d-remote-docker.yaml <<EOF
openclaw:
  remoteDocker:
    dockerHost: ssh://docker-remote@${HOST_LISTEN_ADDRESS}:${SSH_HOST_PORT}
EOF
```

### 2.3 Deploy and run smoke checks

```bash
./scripts/test-local-k3d.sh \
  --release-name platform-stack \
  --namespace ai-homebase \
  --kubeconfig ~/.kube/k3d-ai-homebase-dev.yaml \
  --values-file /tmp/platform-stack-k3d-remote-docker.yaml
```

If you only want the install step:

```bash
./scripts/install.sh --profile k3d
```

To tear down both the cluster and the Incus VM together:

```bash
./scripts/k3d-local-teardown.sh --cluster-name ai-homebase-dev --vm-name openclaw-sandbox
```

Default values layers used by the k3d scripts:

1. `charts/platform-stack/values.yaml`
2. `charts/platform-stack/values-k3d.yaml`

## 3) Service access

Expected local browser endpoints served by the k3d `ingress-nginx` controller:

- `http://wg.localtest.me`
- `http://openhands.localtest.me`
- `http://infisical.localtest.me`

`openclaw` remains service-only by default in the shipped k3d layering.

## 4) Local ingress host access (DNS/hosts)

`*.localtest.me` usually resolves to `127.0.0.1` automatically.
If not, add entries such as:

```text
127.0.0.1 openhands.localtest.me wg.localtest.me infisical.localtest.me openclaw.localtest.me
```

### NixOS host setup notes

If you use NixOS and want the Incus-backed sandbox VM flow, make the host requirements explicit in your system configuration rather than relying on the repository's `shell.nix`. The local bootstrap needs Docker for `k3d`, Incus for the dedicated `openclaw-sandbox` VM, nftables for the Incus bridge/NAT rules, and local host mappings when your machine does not resolve `*.localtest.me` automatically.

A complete example looks like this:

```nix
{
  virtualisation.docker.enable = true;

  virtualisation.incus = {
    enable = true;

    preseed = {
      config = {
        "core.https_address" = "[::]:8443"; # optional
      };

      networks = [
        {
          name = "incusbr0";
          type = "bridge";
          config = {
            "ipv4.address" = "10.10.10.1/24";
            "ipv4.nat" = "true";
            "ipv6.address" = "none";
          };
        }
      ];

      storage_pools = [
        {
          name = "default";
          driver = "dir";
        }
      ];

      profiles = [
        {
          name = "default";
          description = "Default Incus profile";
          config = {};
          devices = {
            eth0 = {
              type = "nic";
              name = "eth0";
              network = "incusbr0";
            };
            root = {
              type = "disk";
              path = "/";
              pool = "default";
            };
          };
        }
      ];
    };
  };

  networking.nftables.enable = true;

  networking.extraHosts = ''
    127.0.0.1 openclaw.localtest.me
    127.0.0.1 openhands.localtest.me
    127.0.0.1 infisical.localtest.me
    127.0.0.1 nextcloud.localtest.me
    127.0.0.1 paperless.localtest.me
    127.0.0.1 wg.localtest.me
  '';

  users.users.yourUser.extraGroups = [ "incus-admin" ];
}
```

Replace `yourUser` with the local account that runs `k3d`, `incus`, and the repository helper scripts. The extra host entries cover every shipped `values-k3d.yaml` hostname; `nextcloud.localtest.me` and `paperless.localtest.me` are only needed if you enable those optional services locally, but keeping them in `extraHosts` avoids surprise DNS mismatches later.

After rebuilding your NixOS configuration, log out/in so the new group membership applies, initialize Incus if needed, and then continue with the k3d bootstrap flow above.

## 5) Sandbox note

The shared OpenClaw defaults now render the Docker sandbox backend with explicit `docker.*` and `browser.*` settings, and the supported path keeps remote-Docker wiring enabled by default. Operators still need an OpenClaw image that includes Docker CLI + OpenSSH client and an environment-appropriate `browser.cdpSourceRange`. OpenHands continues to use the upstream in-cluster Kubernetes runtime.

## 6) Incus sandbox VM note

The Incus VM assets live outside the Helm charts:

- `incus/openclaw-sandbox-user-data.tpl` contains the cloud-init user-data definition for the guest.
- `scripts/incus-vm-up.sh` creates or reuses the VM, derives the bridge gateway from the Incus network, assigns a stable guest IPv4 on the Incus bridge, renders and applies the instance-specific NoCloud `network-config` before first boot, configures an Incus NAT-mode SSH proxy, waits up to 600 seconds by default for SSH readiness on first boot, and writes the resolved connection details to `~/.local/state/ai-homebase/incus/<vm-name>.env`.
- `scripts/incus-vm-down.sh` deletes just the VM.
- `scripts/k3d-local-teardown.sh` removes both the k3d cluster and the Incus VM.

This keeps the VM independently managed from Helm while still making it part of the local bootstrap lifecycle.
