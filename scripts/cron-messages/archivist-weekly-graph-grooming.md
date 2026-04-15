Run weekly graph grooming.

Use the `groom-recent-memories` skill. This is a scheduled weekly run, not an OpenClaw heartbeat. Read `state/grooming-checkpoint.json`, construct the Qdrant and Nextcloud deltas from that checkpoint, and keep the pass bounded.

Grooming contract:
- trigger: `weekly`
- run from the last successful weekly grooming window when available, plus graph-link catch-up from `last_successful_graph_link`
- inspect only changed or registered high-value Nextcloud surfaces
- upsert/link Memgraph first, then annotate Qdrant points with graph-link payloads
- advance checkpoint fields only after Memgraph links and Qdrant annotations succeed
- append one row to Nextcloud `/Projects/ai-homebase/archivist-grooming-log.md` with the run ID, window, counts, checkpoint update, and issues

If the run cannot complete safely, record the issue in the grooming log and leave successful checkpoint timestamps unchanged.
