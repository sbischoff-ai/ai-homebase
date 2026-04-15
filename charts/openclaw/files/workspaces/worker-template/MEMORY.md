# Memory - {{WORKER_NAME}}

Default: this worker does not use Qdrant unless its definition explicitly requires it.

Use this file only for local retrieval hints.

If this worker does use Qdrant, retrieve from cues in `CURRENT.md` and `SURFACES.md` rather than broad memory dumps.

When a worker definition allows Qdrant writes, store one atomic durable claim per memory, use 1 to 3 compact self-contained sentences, and include natural retrieval anchors such as project slug, service/component, artifact path, aliases, or source reference in the `information` text. Important recall terms must appear in `information`, not only in metadata.

{{WORKER_MEMORY_INSTRUCTIONS}}
