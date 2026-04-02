# Sandbox Network Access

This matrix documents which OpenClaw agents can reach which services from their runtime environment.

| Agent | Memgraph (Bolt 7687) | Gitea (HTTP) | Registry (HTTPS) | Nextcloud | Qdrant | Internet |
| --- | --- | --- | --- | --- | --- | --- |
| `main` | via gateway | via MCP | N/A | via MCP | via MCP | yes |
| `architect` | no sandbox | via MCP | N/A | via MCP | via MCP | yes |
| `coder` | **no** (intentional) | **yes** (direct) | **yes** (direct) | via MCP | via MCP | yes |
| `archivist` | **yes** (direct) | via MCP | N/A | via MCP | via MCP | limited |
| `watchdog` | no sandbox | N/A | N/A | via MCP | via MCP | limited |

Notes:

- `via MCP` means access flows through the MCP bridge on the gateway, not directly from the sandbox container.
- `direct` means the sandbox container can reach the service directly through Incus VM routing.
- `no sandbox` means the agent runs unsandboxed on the gateway.
- Coder's lack of Memgraph access is intentional. Graph data operations belong to `archivist`.
- `limited` internet access indicates a narrower outbound posture than the general-purpose agents.
