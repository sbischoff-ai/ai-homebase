# Memgraph Lab chart

This chart deploys Memgraph Lab as an in-cluster UI for Memgraph.

## Default posture

- Image pinned to `memgraph/lab:3.9.0`
- HTTP service on port `3000`
- Connects to in-cluster Memgraph by default (`platform-stack-memgraph:7687`)
- Dedicated ingress hostname support via `global.hosts.memgraphLab` or `ingress.defaultHost`
