# Secrets and SOPS

The canonical first-run secret path in this repository is `scripts/bootstrap-secrets.sh`.

The `secrets/` directory is the operator workspace for optional encrypted-manifest management after bootstrap:

- Plaintext templates live as `secrets/*.yaml` and are gitignored.
- Encrypted manifests live as `secrets/*.enc.yaml` and are intended to be committed.
- [`secrets/.sops.yaml`](../secrets/.sops.yaml) is committed so every operator uses the same encryption rule.

## Generate an age keypair

Generate the keypair on an operator-controlled machine:

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
grep '^# public key:' ~/.config/sops/age/keys.txt
```

Copy the generated public key into [`secrets/.sops.yaml`](../secrets/.sops.yaml) in place of `age1...REPLACE_ME`.

Keep `~/.config/sops/age/keys.txt` private. Do not commit it, mount it into coder sandboxes, or place it in shared bootstrap artifacts.

## Fill and encrypt the templates

The repo now ships plaintext templates for the currently migrated Secrets:

- `secrets/openclaw-secrets.yaml`
- `secrets/coder-credentials.yaml`
- `secrets/reviewer-credentials.yaml`
- `secrets/nextcloud-config-secrets.yaml`

Recommended workflow:

```bash
cp secrets/openclaw-secrets.yaml secrets/openclaw-secrets.enc.yaml
cp secrets/coder-credentials.yaml secrets/coder-credentials.enc.yaml
cp secrets/reviewer-credentials.yaml secrets/reviewer-credentials.enc.yaml
cp secrets/nextcloud-config-secrets.yaml secrets/nextcloud-config-secrets.enc.yaml
```

Edit the `.enc.yaml` copies and replace every `replace-me` value with the real secret material.

Then encrypt them in place:

```bash
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
sops --encrypt --in-place secrets/openclaw-secrets.enc.yaml
sops --encrypt --in-place secrets/coder-credentials.enc.yaml
sops --encrypt --in-place secrets/reviewer-credentials.enc.yaml
sops --encrypt --in-place secrets/nextcloud-config-secrets.enc.yaml
```

At that point:

- Keep the plaintext `secrets/*.yaml` files local only.
- Commit the encrypted `secrets/*.enc.yaml` files.
- Apply or sync only the encrypted manifests through the GitOps path.

## Argo CD SOPS decryption

Argo CD must decrypt the committed `*.enc.yaml` files inside `argocd-repo-server` before applying them.

Supported pattern:

1. Install a SOPS-capable repo-server integration such as `ksops` or a maintained `helm-secrets`/SOPS plugin.
2. Mount the age private key into `argocd-repo-server`, typically via a Secret and `SOPS_AGE_KEY_FILE`.
3. Point the Argo CD Application source at the encrypted manifests so repo-server renders plaintext Kubernetes Secrets only in-memory during sync.

Operational constraints:

- The public age recipient belongs in [`secrets/.sops.yaml`](../secrets/.sops.yaml).
- The private age key belongs only on trusted operator machines and in the Argo CD repo-server decryption path.
- Do not distribute the private key to developer laptops, generic CI runners, or coder sandboxes.

## Coder agent constraint

The coder sandbox may hold the public age recipient because encryption is safe with the public key alone.

The coder sandbox must not receive:

- the age private key
- `SOPS_AGE_KEY_FILE`
- decrypted Secret values

That keeps the coding environment encrypt-only. Operators can ask coder to prepare manifest structure, but final value entry and encryption with the real private key must happen outside the sandbox.

## Current repo templates

The repo currently ships plaintext templates for:

- `openclaw-secrets`
- `coder-credentials`
- `reviewer-credentials`
- `nextcloud-config-secrets`

Use `scripts/bootstrap-secrets.sh` for the first install, and use encrypted manifests from `secrets/` when you want those long-lived secrets committed and synced through GitOps afterward.
