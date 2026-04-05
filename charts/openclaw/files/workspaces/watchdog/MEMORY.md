# Memory - Watchdog

Qdrant is the durable shared semantic memory layer. Use this file only for local retrieval hints.

## Search

Use `qdrant-find` when:
- an incident may match a prior pattern
- a baseline might already exist
- an escalation path may already be documented

## Store

Use `qdrant-store` for:
- durable monitoring rules
- recurring failure signatures
- baseline summaries
- durable incident-pattern findings

Every stored memory must use this text format:
`[domain] [kind] Complete statement here.`

Every stored memory must include metadata with at least:
`{"kind":"...","domain":"...","agent":"watchdog","created":"ISO-8601"}`

Include `nc_refs` when the durable artifact lives in Nextcloud.
