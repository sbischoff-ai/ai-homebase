# GitOps Bootstrap

This page covers the GitOps handoff that adds Argo CD, pushes the repo snapshot into in-cluster Gitea, seeds the companion sandbox-images repo, triggers the first sync, and validates the resulting Argo CD applications.

## When to Run It

The normal `bootstrap-stack.sh` and `k3d-local-bootstrap.sh` workflows now run the GitOps handoff automatically before they return.

```bash
./scripts/bootstrap-gitops.sh --profile <k3d|k3s> --bootstrap-config bootstrap.local.toml
```

Use the standalone command when you intentionally want to refresh or replay the GitOps handoff against a cluster that already has the pre-GitOps shared bootstrap resources in place. `bootstrap-stack.sh` itself is not considered complete until the GitOps handoff succeeds.

## What It Does

The script performs eight steps:

1. reapplies the existing `platform-stack` Helm path through `bootstrap-stack.sh --enable-service argo-cd`
2. reads the bootstrap-managed Gitea admin credentials from Kubernetes
3. creates or updates the dedicated coder-owned GitOps user, the shared reviewer user, and the private bootstrap repos in Gitea
4. pushes a self-contained snapshot of the local charts and cluster values to that repo
5. pushes a slim sandbox-images source snapshot to the dedicated sandbox-images repo
6. adds the reviewer user as a collaborator on both repos and protects the default branch for the standard internal review flow
7. registers the GitOps repo in Argo CD and applies the Argo CD `AppProject` and `Application` objects
8. triggers the first explicit Argo CD sync for the root and platform applications
9. waits until both applications report `Synced` and `Healthy`

The generated repo uses an app-of-apps shape, but the child app is the single `platform-stack` application. Argo CD is therefore self-managed through the umbrella chart instead of through a second standalone Argo CD release.

The generated repo is a snapshot of the local `charts/` tree plus cluster-specific values at bootstrap time. A chart fix in this repo does not reach the running cluster until `bootstrap-stack.sh` or `bootstrap-gitops.sh` is rerun and a new commit is pushed into the in-cluster GitOps repo. Replays update the existing protected branch with a regular commit; they do not replace branch history with a force-push.

## Bootstrap Config Inputs

The GitOps handoff reads these values from `bootstrap.local.toml`:

- `hosts.argocd`
- `gitops.cluster_name`
- `gitops.repo_name`
- `gitops.sandbox_images_repo_name`
- `gitops.repo_branch`
- `gitops.repo_private`
- `gitops.project`
- `openclaw.agents.coder.gitea.username`
- `openclaw.agents.coder.gitea.email`
- `openclaw.agents.coder.gitea.password`
- `openclaw.agents.reviewer.gitea.username`
- `openclaw.agents.reviewer.gitea.email`
- `openclaw.agents.reviewer.gitea.password`

If `openclaw.agents.coder.gitea.password` is empty, the bootstrap flow generates a fresh first-run coder GitOps password and stores it in the bootstrap-managed Secrets created during install.
If `openclaw.agents.reviewer.gitea.password` is empty, the bootstrap flow generates a fresh first-run reviewer password and stores it in the bootstrap-managed Secrets created during install.

## Operating Model

After the GitOps bootstrap succeeds:

- the GitOps repo becomes the source of truth for cluster definitions
- the sandbox-images repo becomes the source of truth for the regular and coder OpenClaw sandbox image definitions
- Argo CD keeps sync in manual mode because agents may be allowed to push changes to the GitOps repo; sync should therefore be triggered explicitly through the UI or API
- sandbox image tags referenced from OpenClaw config should be published to the in-cluster registry before GitOps changes point at them
- direct `helm upgrade` should be treated as break-glass only

The Argo CD repository Secret is not committed to git. It is created directly in the cluster and points at the in-cluster Gitea service URL.
