# Memgraph chart

This chart deploys Memgraph as an in-cluster graph database service.

## Default posture

- Image pinned to `memgraph/memgraph:3.8.1`
- Bolt service on port `7687`
- HTTP service on port `7444`
- Persistent data mounted at `/var/lib/memgraph`
- Dedicated ingress hostname support via `global.hosts.memgraph` or `ingress.defaultHost`
