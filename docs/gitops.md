# GitOps Bootstrap

This page covers the GitOps handoff that adds Argo CD and hands cluster changes over to an in-cluster Gitea repository.

## When to Run It

Run the GitOps bootstrap after the normal `bootstrap-stack.sh` or `k3d-local-bootstrap.sh` workflow is healthy.

```bash
./scripts/bootstrap-gitops.sh --profile <k3d|k3s> --bootstrap-config bootstrap.local.toml
```

## What It Does

The script performs five steps:

1. reapplies the existing `platform-stack` Helm path through `bootstrap-stack.sh --skip-secrets --enable-service argo-cd`
2. reads the bootstrap-managed Gitea admin credentials from Kubernetes
3. creates or updates a dedicated GitOps robot user and private repo in Gitea
4. pushes a self-contained snapshot of the local charts and cluster values to that repo
5. registers the repo in Argo CD and applies the Argo CD `AppProject` and `Application` objects

The generated repo uses an app-of-apps shape, but the child app is the single `platform-stack` application. Argo CD is therefore self-managed through the umbrella chart instead of through a second standalone Argo CD release.

## Bootstrap Config Inputs

The GitOps handoff reads these values from `bootstrap.local.toml`:

- `hosts.argocd`
- `gitops.cluster_name`
- `gitops.repo_name`
- `gitops.repo_branch`
- `gitops.repo_private`
- `gitops.project`
- `gitops.robot_username`
- `gitops.robot_email`
- `gitops.robot_password`

If `gitops.robot_password` is empty, the bootstrap script preserves the existing in-cluster GitOps password when present or generates a new one. After the first GitOps bootstrap, the in-cluster GitOps Secret becomes the password source of truth for reruns.

## Operating Model

After the GitOps bootstrap succeeds:

- the Gitea repo becomes the source of truth for the cluster
- Argo CD keeps sync in manual mode because agents may be allowed to push changes to the GitOps repo; sync should therefore be triggered explicitly through the UI or API
- direct `helm upgrade` should be treated as break-glass only

The Argo CD repository Secret is not committed to git. It is created directly in the cluster and points at the in-cluster Gitea service URL.
