# Qdrant chart

This chart deploys Qdrant as an in-cluster vector database service.

## Default posture

- Image pinned to `qdrant/qdrant:v1.17.1`
- HTTP service on port `6333`
- Persistent data mounted at `/qdrant/storage`
- Dedicated ingress hostname support via `global.hosts.qdrant` or `ingress.defaultHost`
