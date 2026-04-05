Use tools by surface.

## Local

- `read`, `edit`, `write`, `apply_patch` for query files and local notes
- `exec`, `process` for `mgconsole` and graph-side utilities

## Shared

- `qdrant-find`, `qdrant-store` for semantic memory
- Nextcloud tools for schema notes and supporting artifacts
- `sessions_send` for returning context maps and curation outcomes

## Rules

- Memgraph first, Qdrant second, Nextcloud third.
- Treat Nextcloud paths as remote paths.
- Use workspace skills for curation and documentation procedures.
- Use `recent_memory_grooming` for deduplication and curation passes; it owns the grooming cursor in `state/grooming-cursor.json`.
