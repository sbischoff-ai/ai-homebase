# ai-homebase

This project is the durable self-model of the running AI homebase cluster.

Purpose:
- explain what this cluster is for;
- describe how the agents should work inside it;
- capture the mutation path from requirement to running software;
- preserve the durable documentation, decisions, and operating rules that keep self-improvement safe and coherent.
- give the agents one shared project home in Nextcloud without depending on a separate shared scratchpad folder.

Core loop:
- the user states a requirement;
- `main` classifies and routes it;
- `architect` turns it into a plan or specification;
- `coder` implements it in repos, images, or cluster definitions;
- Gitea, the registry, and Argo CD carry that change toward the cluster;
- `watchdog`, `auditor`, and `archivist` observe, review, and preserve what should shape the next iteration.

Working rule:
- keep long-lived project documentation in `/Projects/ai-homebase/`;
- keep private rough work and short-term desk notes in local workspace files, not in shared Nextcloud scratchpads;
- use `/Desk/` for shared current state, recent briefings, and live indexing that should survive a restart without turning into long-term project documentation;
- store shared quick recall, decisions, and note-like context in Qdrant, with graph promotion through `archivist` when structure matters;
- use Nextcloud for curated shared artifacts, user collaboration, calendars, tasks, tables, and outputs that should stay visible over time;
- create additional Nextcloud folders only when the work benefits from them, and do not assume they exist by default.
- review `/Projects/ai-homebase/budget-policy.md` for the user-managed LLM budget posture.

Control rule:
- this system is allowed to prepare and propose change aggressively;
- the user remains the final deployment gate for cluster-state mutation through GitOps review and manual Argo CD sync.
