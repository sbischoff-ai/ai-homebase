# Qdrant MCP chart

This chart deploys the official Qdrant MCP server as a dedicated MCP companion service.

## Default posture

- Image pinned to `python:3.12-slim`
- HTTP service on port `8000`
- Connects to in-cluster Qdrant by default (`http://platform-stack-qdrant:6333`)
- Bootstraps `mcp-server-qdrant==0.8.0` into a runtime venv on container start
- Uses `EMBEDDING_PROVIDER=fastembed` and `EMBEDDING_MODEL=BAAI/bge-base-en-v1.5`
- Sets repo-managed `TOOL_STORE_DESCRIPTION` and `TOOL_FIND_DESCRIPTION` defaults that enforce the shared memory schema
- Guides agents to store atomic, retrieval-optimized memory text and to filter metadata through nested Qdrant payload keys such as `metadata.kind` and `metadata.project`

## Required values

- `qdrant.url`: upstream Qdrant base URL for vector storage
- `qdrant.collectionName`: default collection used by the memory tools
- `embedding.provider`: embedding provider name
- `embedding.model`: embedding model name
- `toolDescriptions.store`: MCP store tool instructions shown to the model
- `toolDescriptions.find`: MCP find tool instructions shown to the model
