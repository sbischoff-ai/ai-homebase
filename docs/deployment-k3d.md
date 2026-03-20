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
- generates bootstrap secrets and now validates the remote Docker SSH private key plus `known_hosts` material before deployment,
- deploys `platform-stack` with `values.yaml + values-k3d.yaml`, and
- runs local smoke checks.

The bootstrap exports `KUBECONFIG` to the dedicated kubeconfig path for the lifetime of the script so nested `kubectl` and `helm` calls all target the same local cluster.
The local k3d bootstrap also disables the default k3s Traefik add-on during cluster creation so Helm-managed `ingress-nginx` is the single intended HTTP/HTTPS ingress controller. It still uses Docker to run the local k3d node containers themselves, while OpenClaw is configured by default to target the Incus-backed remote Docker daemon over SSH and therefore expects an OpenClaw image that includes Docker CLI + OpenSSH client support.
The same local bootstrap now also creates a separate lightweight Incus VM (`openclaw-sandbox` by default) from `images:debian/12/cloud`, sized for **2 vCPU**, **6 GiB RAM**, and a small dedicated root disk. The guest installs only Docker Engine, SSH, and minimal supporting packages so it can act as a narrow remote Docker sandbox appliance for OpenClaw Docker/browser sandboxes. On the host side, the requirements stay minimal: initialized Incus, a bridge network such as `incusbr0`, and a storage/profile setup that can boot a VM. The bootstrap script handles the instance-specific guest networking itself by deriving the bridge gateway from `incus network get <bridge> ipv4.address`, assigning a stable guest IPv4, and rendering an explicit NoCloud `network-config` before first boot. Because VM guest NIC names are not guaranteed to match Incus device aliases such as `eth0`, the helper now reads `volatile.eth0.hwaddr` from `incus config show <vm>` and matches the guest NIC by MAC in cloud-init before applying the static IPv4, a cloud-init/netplan-compatible default IPv4 route (`to: 0.0.0.0/0`), and DNS resolvers. It still keeps the Incus-side `eth0` device override for the static address reservation and records the resolved host listen address in `~/.local/state/ai-homebase/incus/<vm-name>.env` so the k3d bootstrap can point OpenClaw at the same reachable endpoint. Before `incus start`, `scripts/incus-vm-up.sh` now also validates the active bridge DNS posture, logs whether guests will use explicit `dns.nameservers` resolvers or the bridge gateway fallback, and fails early when the bridge cannot safely satisfy that DNS assumption.
On the first boot, cloud-init inside that VM installs Docker Engine and SSH packages, so readiness can take several minutes. `scripts/incus-vm-up.sh` now waits up to 600 seconds by default, and operators can override that with `SSH_READY_TIMEOUT_SECONDS` or `--ssh-ready-timeout-seconds`. If cloud-init reaches a terminal failure state inside the guest, the helper now stops waiting immediately and records host-side Incus state plus guest-side diagnostics such as `cloud-init status --long`, `journalctl -u cloud-init --no-pager`, and the Incus console log so first-boot failures are easier to debug.

## 2) Manual flow

### 2.1 Bootstrap the local cluster

```bash
./scripts/k3d-up.sh --cluster-name ai-homebase-dev
./scripts/incus-vm-up.sh --vm-name openclaw-sandbox
source ~/.local/state/ai-homebase/incus/openclaw-sandbox.env
```

`k3d-up.sh` disables the bundled k3s Traefik deployment so `ingress-nginx` remains the only intended HTTP/HTTPS ingress controller in the local cluster. k3d itself still runs on Docker to host the local cluster.
Expect the Incus helper to spend a few minutes on the very first run while cloud-init installs Docker Engine and SSH; it now seeds both NoCloud user-data and an instance-specific NoCloud `network-config` before boot so package installation does not depend on implicit bridge/cloud-image networking or DHCP defaults inside the guest. That network config no longer assumes the guest-visible NIC is literally named `eth0`; it matches by the Incus-reported MAC so predictable-interface names inside the VM do not break bootstrap. If your machine is slower than the default 600-second wait, pass `--ssh-ready-timeout-seconds <seconds>` or export `SSH_READY_TIMEOUT_SECONDS`.

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

The bootstrap now fails early if the remote Docker private key is missing/empty or if `ssh-keyscan` does not produce a non-empty `known_hosts` file for the target host and port. That keeps the generated `openclaw-remote-docker-ssh` Secret aligned with the OpenClaw chart contract before Helm deploys resources.

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

If you only need the generic install, lint, template, or helper-script commands outside this k3d-specific workflow, use [`docs/commands.md`](./commands.md).

To tear down both the cluster and the Incus VM together:

```bash
./scripts/k3d-local-teardown.sh --cluster-name ai-homebase-dev --vm-name openclaw-sandbox
```

Default values layers used by the k3d scripts:

1. `charts/platform-stack/values.yaml`
2. `charts/platform-stack/values-k3d.yaml`

## 3) Service access

Expected local browser endpoints served by the k3d `ingress-nginx` controller:

- `http://openhands.localtest.me`
- `http://infisical.localtest.me`

`openclaw` is exposed through the shipped k3d ingress layering by default.

## 4) Local ingress host access (DNS/hosts)

`*.localtest.me` usually resolves to `127.0.0.1` automatically.
If not, add entries such as:

```text
127.0.0.1 openhands.localtest.me infisical.localtest.me openclaw.localtest.me
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
- `scripts/incus-vm-up.sh` creates or reuses the VM, derives the bridge gateway from the Incus network, assigns a stable guest IPv4 on the Incus bridge, reads `volatile.eth0.hwaddr` from `incus config show <vm>` so the instance-specific NoCloud `network-config` matches the guest NIC by MAC instead of assuming the guest-visible name is `eth0`, configures an Incus NAT-mode SSH proxy, waits up to 600 seconds by default for SSH readiness on first boot, and writes the resolved connection details to `~/.local/state/ai-homebase/incus/<vm-name>.env`.
- `scripts/incus-vm-down.sh` deletes just the VM.
- `scripts/k3d-local-teardown.sh` removes both the k3d cluster and the Incus VM.

This keeps the VM independently managed from Helm while still making it part of the local bootstrap lifecycle.
