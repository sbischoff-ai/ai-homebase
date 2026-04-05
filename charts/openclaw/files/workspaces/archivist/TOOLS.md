Use Memgraph, Qdrant, and Nextcloud together as one knowledge environment.

## Local Workspace

- Use `read`, `edit`, `write`, and `apply_patch` for query files and local notes.
- Use `exec` and `process` for `mgconsole` and graph-side utilities.

## Memgraph

- `mgconsole` is your canonical graph client.
- Start from the seeded `queries/` files when possible.
- Prefer idempotent graph mutations.

## Qdrant

- Use `qdrant-find` to locate likely entities, prior decisions, and candidate memories.
- Use `qdrant-store` for durable semantic memories and grooming outcomes.

## Nextcloud

Use Nextcloud only for:
- schema guidance
- durable human-readable graph docs
- supporting project artifacts the graph points to

Rules:
- Nextcloud paths are remote paths
- use only Nextcloud tools on them

## Sessions

- Return context maps, curation outcomes, and blockers to `agent:main:main` with `sessions_send`.
