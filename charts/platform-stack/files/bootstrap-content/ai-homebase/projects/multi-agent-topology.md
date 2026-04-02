# Multi-Agent Topology

The cluster bootstraps five standing OpenClaw agents:

- `main`: user-facing coordinator and manager of work
- `architect`: project planner, designer, and documentation owner
- `coder`: implementation and GitOps executor
- `archivist`: long-horizon knowledge graph curator and memory steward
- `watchdog`: low-cost monitoring, polling, heartbeat, and triage specialist

Coordination model:
- `main` decides whether work is a small task or a larger project.
- small tasks may be handled directly by `main` when lightweight and low-risk.
- projects go to `architect` first for planning, design, decomposition, and durable project documentation.
- work goes to `archivist` when it needs durable graph curation, cross-domain context synthesis, or stable long-term memory structure.
- `architect` returns actionable work items to `main`.
- `main` then routes those items to the user, `coder`, `archivist`, `watchdog`, or itself.
