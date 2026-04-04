# GitOps Workflow

This stack is designed to evolve through repository changes, image publishing, and GitOps handoff.

Canonical mutation chain:
1. the user states a requirement;
2. `main` routes it;
3. `architect` defines the plan, design direction, and task decomposition when the work is non-trivial;
4. `coder` applies cluster and application changes in the relevant repository;
5. `coder` maintains the OpenClaw sandbox image source repo and publishes resulting images to the in-cluster registry;
6. `coder` validates changes with the documented lint and render commands;
7. cluster-definition changes are pushed to the GitOps repo;
8. sandbox runtime changes are pushed to the sandbox-images repo and published to the registry before those tags are referenced from cluster config;
9. the user reviews the diff and syncs Argo CD manually;
10. `watchdog`, `auditor`, and `archivist` feed observations, findings, and durable knowledge back into the next iteration.

Repository roles:
- the GitOps repo is the source of truth for cluster definitions;
- the sandbox-images repo is the source of truth for OpenClaw runtime image source;
- the registry is the canonical artifact distribution layer for those images.

Self-mutation rule:
- this system is allowed to prepare its own mutations;
- the manual Argo CD sync step is the operator control boundary for infrastructure mutation.

Important constraint:
- `coder` executes changes;
- `architect` should shape the work when a project needs planning or design first.
