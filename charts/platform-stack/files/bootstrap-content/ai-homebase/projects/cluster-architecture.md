# Cluster Architecture

The cluster centers on OpenClaw as the coordination layer and uses supporting services as one integrated AI control system.

Important components:
- OpenClaw for multi-agent coordination
- Nextcloud for durable shared storage, project documentation, and operator-visible system memory
- Gitea for source control, the GitOps repo, and the sandbox-images repo
- the in-cluster registry for canonical OpenClaw sandbox image distribution
- Argo CD for GitOps application delivery
- shared PostgreSQL and Redis for stateful services
- Qdrant for semantic memory and Memgraph for graph-structured long-term knowledge

Control-plane perspective:
- OpenClaw provides reasoning, delegation, and execution control;
- Nextcloud provides durable human-readable documentation and shared project artifacts;
- Gitea and the registry provide the mutable artifact layer for code and runtime images;
- Argo CD provides the reviewed path from repo state to running cluster state;
- Qdrant and Memgraph provide the durable memory and relationship layer that let the system reason across time instead of only within a single chat.

Runtime model:
- the OpenClaw gateway owns durable state;
- specialist execution happens through standing agents;
- coder can use the remote Docker sandbox path for implementation work and owns the sandbox image source/publish workflow;
- archivist curates Memgraph and the graph-linked Qdrant memory layer;
- watchdog stays in the gateway for low-cost observation and triage.
- auditor reviews plans, implementations, and operating patterns, then proposes optimizations and stronger automation paths.
