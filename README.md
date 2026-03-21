# ai-homebase

`ai-homebase` is a Helm-based homelab stack for running an AI control plane around OpenClaw, with optional services such as Nextcloud, Paperless-ngx, Gitea, and Infisical.

The repository intentionally supports two targets: `k3d` for local testing and `k3s` for the productive homelab server. Shared Helm values provide the baseline platform posture, while target overlays keep local and homelab deployment behavior explicit.

## Start here

- Read the [documentation index](./docs/README.md) for the full map of deeper guides.
- Review [configuration and values layering](./docs/configuration.md) before changing defaults or overlays.
- Check [service toggles and contracts](./docs/services.md) when you need service-specific behavior or secret wiring.

## Common next actions

### Bootstrap a local `k3d` cluster

```bash
export OPENAI_API_KEY="<your-openai-api-key>"
# or export ANTHROPIC_API_KEY / GEMINI_API_KEY / XAI_API_KEY / MOONSHOT_API_KEY
# and optionally BRAVE_API_KEY / PERPLEXITY_API_KEY for built-in web search
./scripts/k3d-local-bootstrap.sh --cluster-name ai-homebase-dev
```

For the full local workflow, troubleshooting, and teardown steps, start with [`docs/deployment-k3d.md`](./docs/deployment-k3d.md).
The local k3d bootstrap pins a Kubernetes 1.32-compatible k3s image by default; override it with `K3S_IMAGE=<image>` if you need a different supported version.
On success, the bootstrap summary prints the kubeconfig path, the OpenClaw gateway token, the auto-selected default OpenClaw model (when a model-provider API key was exported), and the local OpenClaw, Gitea, and Infisical URLs. If OpenClaw asks for first-use pairing approval, use the documented `kubectl exec ... openclaw devices ...` flow in [`docs/deployment-k3d.md`](./docs/deployment-k3d.md#4-first-use-openclaw-token-and-device-pairing).

### Install to the homelab `k3s` target

```bash
./scripts/install.sh --profile k3s
```

For the validation, install, upgrade, and health-check workflow, use [`docs/runbook-homelab.md`](./docs/runbook-homelab.md).

### Look up operator commands and overlays

- Command reference: [`docs/commands.md`](./docs/commands.md)
- Example overlays: [`examples/README.md`](./examples/README.md)
- Quick target chooser: [`docs/deployment.md`](./docs/deployment.md)

## Internal CA and ingress TLS

The shared platform defaults now deploy `cert-manager`, bootstrap an internal CA, and issue the OpenClaw ingress certificate from that CA. The umbrella toggle and PKI resources remain under `certManager.*`, while upstream subchart values now live under the canonical lowercase `cert-manager:` key in umbrella values files. The Helm values keep cert-manager `cert-manager.io/v1` resources disabled by default so first install can succeed before the CRDs exist; `./scripts/install.sh` automatically performs a two-step bootstrap that enables those resources after the cert-manager CRDs and deployments are ready. Clients that connect to the OpenClaw HTTPS hostname must trust the exported root CA certificate before browsers or API clients will accept the ingress certificate. Never export the CA private key from Kubernetes; only distribute the public CA certificate.

Extract the public CA certificate with:

```bash
kubectl get secret platform-stack-root-ca -n <namespace> -o jsonpath='{.data.ca\.crt}' | base64 -d > platform-stack-root-ca.crt
```

If you override the root CA Secret name or cert-manager resource namespace, adjust the command to match your values.
