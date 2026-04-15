# Monitoring Baselines

## Gateway
- /readyz -> HTTP 200 (expected at all times after startup)
- Startup time: ~30-60 seconds after pod creation

## Sessions
- Standing sessions after bootstrap: 6 (main, architect, coder, archivist, watchdog, auditor)
- Cold-start session response time: 5-30 seconds (expected, not a fault)

## Services
- Nextcloud: HTTP 200 at internal service URL
- Memgraph: Bolt connection on port 7687
- Qdrant: HTTP 200 at internal service URL

## Known Patterns
- sessions_list returns 0 from sandboxed cron context (expected - sandbox isolation)
- First coordination-status marker after deploy may show a stale timestamp (expected - main has not run yet)

Watchdog should update this document as new baselines are established.
