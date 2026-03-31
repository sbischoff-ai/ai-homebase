# GitOps Bootstrap

This page covers the GitOps handoff that adds Argo CD, pushes the repo snapshot into in-cluster Gitea, triggers the first sync, and validates the resulting Argo CD applications.

## When to Run It

The normal `bootstrap-stack.sh` and `k3d-local-bootstrap.sh` workflows now run the GitOps handoff automatically before they return.

```bash
./scripts/bootstrap-gitops.sh --profile <k3d|k3s> --bootstrap-config bootstrap.local.toml
```

Use the standalone command when you intentionally want to refresh the in-cluster GitOps repo snapshot from the current working tree without re-running the full stack bootstrap.

## What It Does

The script performs seven steps:

1. reapplies the existing `platform-stack` Helm path through `bootstrap-stack.sh --skip-secrets --enable-service argo-cd`
2. reads the bootstrap-managed Gitea admin credentials from Kubernetes
3. creates or updates the dedicated coder-owned GitOps user and private repo in Gitea
4. pushes a self-contained snapshot of the local charts and cluster values to that repo
5. registers the repo in Argo CD and applies the Argo CD `AppProject` and `Application` objects
6. triggers the first explicit Argo CD sync for the root and platform applications
7. waits until both applications report `Synced` and `Healthy`

The generated repo uses an app-of-apps shape, but the child app is the single `platform-stack` application. Argo CD is therefore self-managed through the umbrella chart instead of through a second standalone Argo CD release.

The generated repo is a snapshot of the local `charts/` tree plus cluster-specific values at bootstrap time. A chart fix in this repo does not reach the running cluster until `bootstrap-stack.sh` or `bootstrap-gitops.sh` is rerun and the updated commit is pushed into the in-cluster GitOps repo.

## Bootstrap Config Inputs

The GitOps handoff reads these values from `bootstrap.local.toml`:

- `hosts.argocd`
- `gitops.cluster_name`
- `gitops.repo_name`
- `gitops.repo_branch`
- `gitops.repo_private`
- `gitops.project`
- `openclaw.agents.coder.gitea.username`
- `openclaw.agents.coder.gitea.email`
- `openclaw.agents.coder.gitea.password`

If `openclaw.agents.coder.gitea.password` is empty, the bootstrap script preserves the existing in-cluster coder GitOps password when present or generates a new one. After the first GitOps bootstrap, the in-cluster GitOps Secret becomes the password source of truth for reruns.

## Operating Model

After the GitOps bootstrap succeeds:

- the Gitea repo becomes the source of truth for the cluster
- Argo CD keeps sync in manual mode because agents may be allowed to push changes to the GitOps repo; sync should therefore be triggered explicitly through the UI or API
- direct `helm upgrade` should be treated as break-glass only

The Argo CD repository Secret is not committed to git. It is created directly in the cluster and points at the in-cluster Gitea service URL.
