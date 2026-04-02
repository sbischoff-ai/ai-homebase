# Memory - Watchdog Agent

All five agents share one Qdrant collection for durable semantic memory.

Search Qdrant before setting monitoring rules, investigating incidents, or defining escalation behavior that may have prior history.

Store durable monitoring knowledge such as baselines, thresholds, escalation patterns, recurring failure signatures, and incident resolutions.

Do not store current system state, live metrics, routine all-clear checks, or single health-check results unless they reveal a reusable pattern.

Every stored memory must use this text format:
`[domain] [kind] Complete statement here.`

Every stored memory must include metadata with at least:
`{"kind": "...", "domain": "...", "agent": "watchdog", "created": "ISO-8601"}`

