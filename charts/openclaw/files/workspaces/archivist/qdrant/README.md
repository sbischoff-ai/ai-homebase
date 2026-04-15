## Archivist Qdrant Scripts

These scripts are the archivist-only Qdrant REST surface for graph grooming.
Ordinary semantic memory search and storage still goes through `qdrant-find` and `qdrant-store`.

The runtime provides:

- `QDRANT_URL`
- `QDRANT_COLLECTION` (defaults to `openclaw-memory`)
- optional `QDRANT_API_KEY`

## Common Flows

Read the grooming checkpoint before choosing a delta:

```bash
cat state/grooming-checkpoint.json
```

Scroll recent memories into normalized JSONL:

```bash
python3 qdrant/scroll_memories.py --since "2026-04-15T00:00:00Z" --limit 100 --out state/qdrant-candidates.jsonl
```

Scroll unbounded only when explicitly backfilling:

```bash
python3 qdrant/scroll_memories.py --limit 200 --out state/qdrant-backfill.jsonl
```

Filter by project, kind, agent, or tag:

```bash
python3 qdrant/scroll_memories.py --project ai-homebase --kind decision --agent architect --tag gitops --limit 50
```

Inspect graph-link catch-up candidates:

```bash
python3 qdrant/scroll_memories.py --graph-status pending --limit 100 --out state/qdrant-link-catchup.jsonl
```

Fetch one exact Qdrant point after graph traversal returns `MemoryEntry.qdrant_id`:

```bash
python3 qdrant/get_memory.py "<point-id>"
```

Annotate a successfully linked point. This only sets the top-level `graph` payload object; it does not change vectors, `document`, or `metadata`.

```bash
python3 qdrant/set_graph_link.py \
  --point-id "<point-id>" \
  --entity-slug ai-homebase \
  --entity-slug archivist \
  --status linked
```

Preview the payload before writing:

```bash
python3 qdrant/set_graph_link.py --point-id "<point-id>" --entity-slug ai-homebase --dry-run
```

## Normalized Packet Shape

Each JSONL row contains:

- `point_id`
- `document`
- `document_sha256`
- `metadata`
- `payload`

Use `point_id` as the Memgraph `MemoryEntry.qdrant_id`, `qdrant:<point_id>` as the default `MemoryEntry.slug`, and `document_sha256` to detect whether a graph entry still matches the Qdrant memory text.
