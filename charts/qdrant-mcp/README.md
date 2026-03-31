# Qdrant MCP chart

This chart deploys the official Qdrant MCP server as a dedicated MCP companion service.

## Default posture

- Image pinned to `ghcr.io/qdrant/mcp-server-qdrant:v0.8.1`
- HTTP service on port `8000`
- Connects to in-cluster Qdrant by default (`http://platform-stack-qdrant:6333`)
- Uses `EMBEDDING_PROVIDER=openai` and `EMBEDDING_MODEL=text-embedding-3-large`
- Reads `OPENAI_API_KEY` from `openclaw-app-secrets` by default

## Required values

- `qdrant.url`: upstream Qdrant base URL for vector storage
- `qdrant.collectionName`: default collection used by the memory tools
- `embedding.provider`: embedding provider name
- `embedding.model`: embedding model name
