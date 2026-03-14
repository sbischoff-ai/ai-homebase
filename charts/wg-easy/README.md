# wg-easy Helm chart

This chart deploys [wg-easy](https://github.com/wg-easy/wg-easy) with WireGuard UDP and the web UI service.

## Prerequisites

Create a secret that provides the required runtime keys:

- `WG_HOST`: public hostname or IP clients will use to connect.
- `PASSWORD`: wg-easy web UI password.

Example:

```bash
kubectl create secret generic wg-easy-secrets \
  --from-literal=WG_HOST=vpn.example.com \
  --from-literal=PASSWORD='change-me'
```

Then set `existingSecret` to that secret name.

## Values contract

`values.yaml` provides a top-level `wg` block:

- `wg.host` (string, default `""`)
- `wg.subnet` (default `10.8.0.0/24`)

At deployment time, the chart wires:

- Required env vars from `existingSecret`: `WG_HOST`, `PASSWORD`
- Recommended defaults:
  - `WG_DEFAULT_ADDRESS=10.8.0.x`
  - `WG_DEFAULT_DNS=1.1.1.1`
  - `WG_ALLOWED_IPS=0.0.0.0/0`

## Deployment flow

1. Create the required secret (example above).
2. Configure chart values (at minimum `existingSecret`, and service/ingress settings appropriate for your cluster).
3. Install or upgrade:

```bash
helm upgrade --install wg-easy ./charts/wg-easy \
  --set existingSecret=wg-easy-secrets
```

4. Verify rollout:

```bash
kubectl rollout status deploy/wg-easy
```

## VPN connection steps

1. Open the wg-easy UI (via your configured service/ingress endpoint).
2. Log in with the `PASSWORD` from your secret.
3. Create a client profile and download/show the QR code.
4. Import that profile into your WireGuard client.
5. Connect and verify tunnel status in wg-easy.

## Internal OpenClaw access (after VPN connection)

After connecting the VPN, access OpenClaw at:

- `http://openclaw.openclaw.svc.cluster.local`

(Use the in-cluster DNS endpoint from a VPN-connected client with routing configured to cluster networks.)
