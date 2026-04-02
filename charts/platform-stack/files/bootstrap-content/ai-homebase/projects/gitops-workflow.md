# GitOps Workflow

This stack is designed to evolve through repository changes, image publishing, and GitOps handoff.

Core flow:
- `architect` defines plans, design direction, and task decomposition.
- `coder` applies cluster and application changes in the repository.
- `coder` maintains the OpenClaw sandbox image source repo and publishes the resulting images to the in-cluster registry.
- `coder` validates changes with the documented lint and render commands.
- cluster-definition changes are pushed to the GitOps repo.
- sandbox runtime changes are pushed to the sandbox-images repo and published to the registry before those tags are referenced from cluster config.
- the user reviews the diff and syncs Argo CD manually.

Important constraint:
- `coder` executes changes;
- `architect` should shape the work when a project needs planning or design first.
