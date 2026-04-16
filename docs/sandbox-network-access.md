# Sandbox Network Access

This matrix documents which OpenClaw agents can reach which services from their runtime environment.

| Agent | Memgraph (Bolt 7687) | Gitea (HTTP) | Registry (HTTPS) | Nextcloud | Qdrant | Internet |
| --- | --- | --- | --- | --- | --- | --- |
| `main` | via gateway | via MCP | N/A | via MCP | via MCP | yes |
| `architect` | not part of normal workflow | **yes** (direct, reviewer identity) | N/A | via MCP | via MCP | yes |
| `coder` | **no** (intentional) | **yes** (direct) | **yes** (direct) | via MCP | via MCP | yes |
| `archivist` | **yes** (direct) | via MCP | N/A | via MCP | via MCP plus curated direct REST scripts | limited |
| `watchdog` | no sandbox | N/A | N/A | via MCP | via MCP | limited |
| `auditor` | not part of normal workflow | **yes** (direct, reviewer identity) | N/A | via MCP | via MCP | yes |

Notes:

- `via MCP` means access flows through the MCP bridge on the gateway, not directly from the sandbox container.
- `direct` means the sandbox container or gateway runtime can reach the service directly.
- `no sandbox` means the agent runs unsandboxed on the gateway.
- Coder's lack of Memgraph access is intentional. Graph data operations belong to `archivist`.
- Archivist's direct Qdrant REST access is limited to seeded `qdrant/` graph-grooming scripts. Ordinary memory search and storage still goes through Qdrant MCP.
- `limited` internet access indicates a narrower outbound posture than the general-purpose agents.
