# Cluster Architecture

The cluster centers on OpenClaw as the coordination layer and uses supporting services for durable operations.

Important components:
- OpenClaw for multi-agent coordination
- Nextcloud for durable shared storage and project documentation
- Gitea for source control, the GitOps repo, and the sandbox-images repo
- the in-cluster registry for canonical OpenClaw sandbox image distribution
- Argo CD for GitOps application delivery
- shared PostgreSQL and Redis for stateful services
- Qdrant for semantic memory and Memgraph for graph-structured long-term knowledge

Runtime model:
- the OpenClaw gateway owns durable state;
- specialist execution happens through standing agents;
- coder can use the remote Docker sandbox path for implementation work and owns the sandbox image source/publish workflow;
- archivist curates Memgraph and the graph-linked Qdrant memory layer;
- watchdog stays in the gateway for low-cost observation and triage.
