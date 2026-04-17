# Documentation

Use this index as the main wiki map after the top-level [README.md](../README.md).

## Start Here

- Want the big-picture platform shape: [`architecture.md`](./architecture.md)
- Need to choose a target first: [`deployment.md`](./deployment.md)
- Need the full local path: [`deployment-k3d.md`](./deployment-k3d.md)
- Need the full homelab path: [`runbook-homelab.md`](./runbook-homelab.md)

## Platform Model

- [`configuration.md`](./configuration.md): values layering, bootstrap config, and environment-specific inputs
- [`services.md`](./services.md): service toggles, secret contracts, and runtime expectations
- [`openclaw-runtime.md`](./openclaw-runtime.md): OpenClaw gateway image, remote Docker sandbox, CA trust, MCP bridges, and seeded agents
- [`architecture.md`](./architecture.md): platform structure and target model
- [`charts.md`](./charts.md): chart composition and packaging notes

## Deployment And Operations

- [`commands.md`](./commands.md): canonical commands
- [`gitops.md`](./gitops.md): Argo CD handoff and GitOps operating model
- [`k3d-troubleshooting.md`](./k3d-troubleshooting.md): local troubleshooting and implementation details
- [`../examples/README.md`](../examples/README.md): example overlays and layer-on-top patterns

## Security, Networking, And State

- [`security.md`](./security.md): secrets, trust boundaries, internal CA, Vaultwarden admin access, and remote Docker SSH posture
- [`secrets.md`](./secrets.md): SOPS workflow, age keys, and encrypted Secret manifests
- [`networking.md`](./networking.md): ingress model, hostname strategy, TLS posture, and local host access
- [`storage.md`](./storage.md): persistence and backup expectations

## Memory And Agent Workflow

- [`qdrant-memory-schema.md`](./qdrant-memory-schema.md): semantic-memory shape
- [`knowledge-graph-schema.md`](./knowledge-graph-schema.md): graph-memory shape
- [`agent_process_examples/README.md`](./agent_process_examples/README.md): maintainer-side examples for seeded agent workflows
