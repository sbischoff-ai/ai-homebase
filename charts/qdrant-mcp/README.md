# Qdrant MCP chart

This chart deploys the official Qdrant MCP server as a dedicated MCP companion service.

## Default posture

- Image pinned to `python:3.12-slim`
- HTTP service on port `8000`
- Connects to in-cluster Qdrant by default (`http://platform-stack-qdrant:6333`)
- Bootstraps `mcp-server-qdrant==0.8.0` into a runtime venv on container start
- Uses `EMBEDDING_PROVIDER=fastembed` and `EMBEDDING_MODEL=BAAI/bge-base-en-v1.5`

## Required values

- `qdrant.url`: upstream Qdrant base URL for vector storage
- `qdrant.collectionName`: default collection used by the memory tools
- `embedding.provider`: embedding provider name
- `embedding.model`: embedding model name
