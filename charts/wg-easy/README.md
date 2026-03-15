# wg-easy Helm chart

This chart deploys [wg-easy](https://github.com/wg-easy/wg-easy) with WireGuard UDP and the web UI service.

## Runtime requirements (all Kubernetes targets)

This chart aligns with the upstream wg-easy container requirements by setting:

- container capabilities: `NET_ADMIN`, `SYS_MODULE`
- node-level requirements (must be configured on Kubernetes nodes, not in the Pod spec):
  - `net.ipv4.ip_forward=1`
  - `net.ipv4.conf.all.src_valid_mark=1`

Your Kubernetes node/host kernel must also provide WireGuard and **legacy xtables iptables NAT** support.
If either is missing, wg-easy can fail during `wg-quick up wg0` when adding the MASQUERADE rule.

Important: treat this as a **node prerequisite**, not a Pod-spec tuning issue.
Current `wg-easy` / `wg-quick` startup flows still execute legacy `iptables` commands in `PostUp`.

Host verification commands:

```bash
lsmod | grep -E '(^wireguard|^ip_tables|^iptable_filter|^iptable_nat|^nf_nat)'
sudo modprobe wireguard ip_tables iptable_filter iptable_nat
sudo sysctl net.ipv4.ip_forward
sudo sysctl net.ipv4.conf.all.src_valid_mark
sudo iptables -t nat -L >/dev/null
```

Expected outcomes:

- `wireguard`, `ip_tables`, and `iptable_nat` modules load or are already present.
- `iptable_filter` is usually also present.
- `net.ipv4.ip_forward = 1` on the host.
- `net.ipv4.conf.all.src_valid_mark = 1` on the host.
- `iptables -t nat` succeeds (no `Table does not exist` error).

Persist these kernel modules at node boot (distribution-specific: for example `/etc/modules-load.d/*.conf`) so nodes are ready before scheduling wg-easy.

If your Kubernetes nodes are nftables-only / legacy-xtables-disabled, `wg-quick up wg0` can still fail even when WireGuard itself is available.
In that case, run wg-easy only on compatible nodes or redesign networking to avoid wg-easy-managed NAT.

## Prerequisites

Create a secret that provides the required runtime keys:

- `WG_HOST`: public hostname or IP clients will use to connect.
- `PASSWORD_HASH`: bcrypt hash for the wg-easy web UI password.

Example:

```bash
kubectl create secret generic wg-easy-secrets \
  --from-literal=WG_HOST=vpn.example.com \
  --from-literal=PASSWORD_HASH='$2b$12$replace-with-bcrypt-hash'
```

By default, the chart reads these keys from a secret named `<release>-wg-easy-secrets` (for `helm install wg-easy`, that is `wg-easy-wg-easy-secrets`).

Set `existingSecret` to override that name (for example, `wg-easy-secrets`).

## Values contract

`values.yaml` provides a top-level `wg` block:

- `wg.host` (string, default `""`)
- `wg.subnet` (default `10.8.0.0/24`)
- `wg.defaultAddress` (default derived from `wg.subnet`, for example `10.8.0.x`)
- `wg.defaultDns` (default `1.1.1.1`)
- `wg.allowedIPs` (default `0.0.0.0/0`)

At deployment time, the chart wires:

- Required env vars from the configured secret (`existingSecret` if set, otherwise `<release>-wg-easy-secrets`): `WG_HOST`, `PASSWORD_HASH`
- Recommended defaults:
  - `WG_DEFAULT_ADDRESS=10.8.0.x`
  - `WG_DEFAULT_DNS=1.1.1.1`
  - `WG_ALLOWED_IPS=0.0.0.0/0`

## Deployment flow

1. Create the required secret (example above).
2. Configure chart values (at minimum ensure your secret name matches the default or set `existingSecret`; also set service/ingress settings appropriate for your cluster).
3. Install or upgrade:

```bash
helm upgrade --install wg-easy ./charts/wg-easy \
  --set existingSecret=wg-easy-secrets
```

4. Verify rollout:

```bash
kubectl rollout status deploy/wg-easy
```

5. Access the wg-easy UI (when using a direct LoadBalancer/NodePort service):

```bash
http://<cluster-ip>:51821
```

## VPN connection steps

1. Open the wg-easy UI (via your configured service/ingress endpoint).
2. Log in with the original plain-text password used to generate `PASSWORD_HASH`.
3. Create a client profile and download/show the QR code.
4. Import that profile into your WireGuard client.
5. Connect and verify tunnel status in wg-easy.

## Internal OpenClaw access (after VPN connection)

After connecting the VPN, access OpenClaw at:

- `http://openclaw.default.svc.cluster.local:18789`

(Use the in-cluster DNS endpoint from a VPN-connected client with routing configured to cluster networks.)
