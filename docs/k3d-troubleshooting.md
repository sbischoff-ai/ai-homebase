# k3d troubleshooting and internals

Use this page when the concise workflow in [`docs/deployment-k3d.md`](./deployment-k3d.md) is not enough and you need the implementation details behind the local `k3d` path.

## What the bootstrap does

### Cluster bootstrap behavior

- `./scripts/k3d-local-bootstrap.sh` exports `KUBECONFIG` to the dedicated kubeconfig path for the lifetime of the script so nested `kubectl` and `helm` calls all target the same local cluster.
- The local bootstrap disables the default k3s Traefik add-on during cluster creation so Helm-managed `ingress-nginx` is the single intended HTTP/HTTPS ingress controller.
- `scripts/k3d-up.sh` pins `rancher/k3s:v1.32.11-k3s1` by default so the local cluster is new enough for the repository's current cert-manager CRDs.
- `k3d` still uses Docker to run the local cluster node containers.

### OpenClaw sandbox behavior

- OpenClaw is configured by default to target an Incus-backed remote Docker daemon over SSH.
- The supported path expects an OpenClaw image that includes Docker CLI and OpenSSH client support.
- Shared OpenClaw defaults render the Docker sandbox backend with explicit `docker.*` and `browser.*` settings.
- Operators still need an environment-appropriate `browser.cdpSourceRange` when the reachable browser sandbox CIDR differs from the default.

### Incus VM bootstrap behavior

- The bootstrap creates a separate lightweight Incus VM (`openclaw-sandbox` by default) from `images:debian/12/cloud`.
- The default VM sizing is **2 vCPU**, **6 GiB RAM**, and a small dedicated root disk.
- The guest installs only Docker Engine, SSH, and minimal supporting packages so it can act as a narrow remote Docker sandbox appliance.
- On the host side, the minimum expectation is an initialized Incus daemon, a bridge such as `incusbr0`, and storage/profile defaults that can boot a VM.
- First boot can take several minutes because cloud-init installs packages before the helper reports SSH readiness.

## Common failure points

### Incus and guest bootstrap

- `scripts/incus-vm-up.sh` waits up to 600 seconds by default for SSH readiness on first boot.
- If your machine is slower than that default, pass `--ssh-ready-timeout-seconds <seconds>` or export `SSH_READY_TIMEOUT_SECONDS`.
- If cloud-init reaches a terminal failure state inside the guest, the helper stops waiting and records diagnostics such as `cloud-init status --long`, `journalctl -u cloud-init --no-pager`, and the Incus console log.
- If the VM never reaches readiness, inspect the generated host-side env file, the helper logs, and the guest diagnostics before re-running the bootstrap.

### Remote Docker Secret generation

- `./scripts/k3d-bootstrap-secrets.sh` fails early if the remote Docker private key is missing or empty.
- The same helper also fails when `ssh-keyscan` does not produce a non-empty `known_hosts` file for the target host and port.
- Those checks keep the generated `openclaw-remote-docker-ssh` Secret aligned with the OpenClaw chart contract before Helm deploys resources.
- The same helper now forwards any non-empty supported provider/search keys into `openclaw-app-secrets` so the first bootstrap can immediately expose those integrations inside the pod.

### Local ingress and hostname access

- `*.localtest.me` usually resolves to `127.0.0.1`, but some hosts still need explicit local host entries.
- When hostname resolution is wrong, browser access failures can look like an ingress or Helm problem even though the cluster is healthy.

## Networking internals

### How the VM network is derived

- `scripts/incus-vm-up.sh` derives the bridge gateway from `incus network get <bridge> ipv4.address`.
- The helper assigns a stable guest IPv4 and renders an explicit NoCloud `network-config` before first boot.
- The script keeps the Incus-side `eth0` device override for the static address reservation.
- The resolved host listen address is written to `~/.local/state/ai-homebase/incus/<vm-name>.env` so later scripts can point OpenClaw at the same reachable endpoint.

### Why NIC matching is more complex than `eth0`

- VM guest NIC names are not guaranteed to match Incus device aliases such as `eth0`.
- The helper reads `volatile.eth0.hwaddr` from `incus config show <vm>` and matches the guest NIC by MAC address in cloud-init.
- That approach lets cloud-init apply the static IPv4, a default IPv4 route, and DNS resolvers without depending on a predictable guest-visible interface name.

### DNS assumptions

- Before `incus start`, `scripts/incus-vm-up.sh` validates the active bridge DNS posture.
- The helper logs whether guests will use explicit `dns.nameservers` resolvers or the bridge gateway fallback.
- It fails early when the bridge cannot safely satisfy that DNS assumption.

## When to override defaults

Use a targeted override only when you have a clear operator reason, such as:

- A slower workstation needs a longer VM SSH readiness timeout.
- The resolved remote Docker SSH endpoint needs to be pinned into a one-off Helm values override.
- Local DNS or `/etc/hosts` behavior does not resolve `*.localtest.me` correctly.
- You need to expose optional services such as Nextcloud or Paperless locally and want matching host entries.
- You are validating a non-default OpenClaw image or a different `browser.cdpSourceRange`.

## NixOS host setup notes

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
    127.0.0.1 vaultwarden.localtest.me
    127.0.0.1 nextcloud.localtest.me
    127.0.0.1 paperless.localtest.me
  '';

  users.users.yourUser.extraGroups = [ "incus-admin" ];
}
```

Replace `yourUser` with the local account that runs `k3d`, `incus`, and the repository helper scripts. The extra host entries cover every shipped `values-k3d.yaml` hostname; `nextcloud.localtest.me` and `paperless.localtest.me` are only needed if you enable those optional services locally, but keeping them in `extraHosts` avoids surprise DNS mismatches later. `vaultwarden.localtest.me` is included because Vaultwarden is enabled in the shipped k3d profile.

After rebuilding your NixOS configuration, log out/in so the new group membership applies, initialize Incus if needed, and then continue with the k3d bootstrap flow.

## Related files

- `incus/openclaw-sandbox-user-data.tpl` contains the cloud-init user-data definition for the guest.
- `scripts/incus-vm-up.sh` creates or reuses the VM, manages guest networking/bootstrap, waits for SSH readiness, and writes connection details to `~/.local/state/ai-homebase/incus/<vm-name>.env`.
- `scripts/incus-vm-down.sh` deletes just the VM.
- `scripts/k3d-local-teardown.sh` removes both the k3d cluster and the Incus VM.
