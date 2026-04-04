# ai-homebase

This project is the durable self-model of the running AI homebase cluster.

Purpose:
- explain what this cluster is for;
- describe how the agents should work inside it;
- capture the mutation path from requirement to running software;
- preserve the durable documentation, decisions, and operating rules that keep self-improvement safe and coherent.

Core loop:
- the user states a requirement;
- `main` classifies and routes it;
- `architect` turns it into a plan or specification;
- `coder` implements it in repos, images, or cluster definitions;
- Gitea, the registry, and Argo CD carry that change toward the cluster;
- `watchdog`, `auditor`, and `archivist` observe, review, and preserve what should shape the next iteration.

Working rule:
- keep long-lived project documentation in `/Projects/ai-homebase/`;
- keep temporary planning and scratchpad material in `/Notes/ai-homebase/`.

Control rule:
- this system is allowed to prepare and propose change aggressively;
- the user remains the final deployment gate for cluster-state mutation through GitOps review and manual Argo CD sync.
