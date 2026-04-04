# Memory — {{WORKER_NAME}}

{{WORKER_MEMORY_INSTRUCTIONS}}

Default: do not store Qdrant memories unless your execution plan explicitly requires it. If your plan does require memory storage, use this format:

Text: `[real] [{{WORKER_DEFAULT_MEMORY_KIND}}] Statement here.`

Metadata: `{"kind": "{{WORKER_DEFAULT_MEMORY_KIND}}", "domain": "real", "agent": "{{WORKER_ID}}", "created": "ISO-8601"}`
