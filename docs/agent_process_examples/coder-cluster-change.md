# Coder Cluster Change

## Trigger

- Source: `main` or `architect` hands `coder` a task that changes cluster-managed state
- Session type: coder standing main session or a coder sandbox task started from that session

## Guaranteed Starting Context

- coder system prompt and workspace files
- available coding, git, registry, and repo-management tools in the normal coder environment
- the handoff packet itself, if `main` or `architect` provided one

## Context That Must Be Fetched Explicitly

- governing artifact from `architect` when the task is spec-first
- relevant repo state in the GitOps repo and, when needed, the sandbox-images repo
- affected chart values, templates, seed files, and docs
- current image tags and registry references when the change includes image work
- Argo CD application status only when rollout state matters to the task

## Flow

```mermaid
flowchart TD
    T[Cluster change request] --> C0[Read handoff and governing artifact]
    C0 --> C1[Fetch affected repo and values context]
    C1 --> C2{Image change required?}
    C2 -->|no| C3[Edit GitOps or chart source]
    C2 -->|yes| C4[Edit image source and build context]
    C4 --> C5[Publish image to registry]
    C5 --> C3
    C3 --> C6[Render and lint affected manifests]
    C6 --> C7{Rendered output changed?}
    C7 -->|yes| C8[Update golden snapshots and docs]
    C7 -->|no| C9[Keep fixture set unchanged]
    C8 --> C10[Prepare reviewable repo change]
    C9 --> C10
    C10 --> C11[Send for review through normal repo flow]
    C11 --> C12{Approved and merged?}
    C12 -->|yes| C13[Confirm GitOps source is ready]
    C12 -->|no| C14[Revise or stop]
    C13 --> C15[Hand back status to main]
```

## Step Notes

1. Coder should treat the GitOps repo as the cluster source of truth and direct `helm upgrade` as break-glass only.
2. If the task changes sandbox or application images, coder updates the image source and the GitOps references together.
3. If a chart, values file, template-consumed file, or workspace seed file changes rendered manifests, coder should treat that as a render-impacting change and update golden snapshots in the same change.
4. Docs should move with the change when values, toggles, service posture, or operator workflow semantics change.
5. Coder should not assume that merging a repo change automatically means the cluster is already updated; rollout state is separate from code state.

## Escalation And Output

- durable outputs: commits, branches, pull requests, image tags, updated docs, and validation artifacts
- user-facing or coordinator-facing status returns to `main`
- deployment confirmation should reference GitOps and Argo CD state, not just local repo success

## Prompt-Writing Pitfalls

- do not tell coder to mutate the cluster directly when the normal path is repo plus GitOps
- do not describe image publication as optional when manifests will reference a new tag
- do not omit render or golden checks for changes that alter manifests
- do not imply that `coder` can skip the governing artifact when `architect` already defined one
