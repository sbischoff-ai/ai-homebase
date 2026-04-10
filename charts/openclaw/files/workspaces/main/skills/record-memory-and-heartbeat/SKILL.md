---
name: record-memory-and-heartbeat
description: Use when main needs to decide what durable facts belong in Qdrant or when to update the shared heartbeat file. Covers memory triggers, nc_refs, and the exact heartbeat write shape.
---

# Memory And Heartbeat

Use this skill after meaningful coordination work.

## Search Trigger

Read the local desk and the relevant shared Nextcloud `/Desk/` cues first.
Search Qdrant before non-trivial coordination, especially when prior context, preferences, or project history may matter.
Prefer small recency-scoped searches guided by active project slugs, people, services, and open loops.

## Store Triggers

Store a Qdrant memory when:
- a durable user preference becomes clear
- a project-level decision is made
- a handoff creates or changes a durable artifact
- a stack-level operating rule changes

When a memory corresponds to a Nextcloud artifact, include `nc_refs`.
When a memory is project-specific, set `project`.
Add 1 to 4 short `tags` for discoverability.
Use `expiry` for short-lived current-context memories that should stop shaping retrieval after the near term.

Use desk promotion first when the information is only short-term continuity:
- local-only current state -> `CURRENT.md` or `daily/`
- cross-agent or user-relevant current state -> Nextcloud `/Desk/current.md` or Nextcloud `/Desk/daily/`
- durable recall -> Qdrant
- structural world-model changes -> archivist plus Memgraph

## Heartbeat

After meaningful coordination work:
- refresh `CURRENT.md` and the latest local note when short-term continuity changed
- promote cross-agent or user-relevant current state into Nextcloud `/Desk/current.md` or Nextcloud `/Desk/daily/` when it should survive a restart
- register newly important shared surfaces in Nextcloud `/Desk/index.md`
- capture user-relevant decisions in Nextcloud when they belong in a durable artifact
- store durable new preferences or rules in Qdrant when recall should survive the current work
- refresh Nextcloud `/Projects/ai-homebase/heartbeat.json` when shared coordination state changed in a way watchdog should notice
- do nothing extra when nothing durable changed

When you refresh the shared heartbeat file, write:
`{"lastActivity":"ISO-8601","agent":"main","status":"ok"}`

## Boundaries

- Do not treat local retrieval hints as the primary long-term memory system.
- Do not treat Nextcloud `/Desk/` as a general archive.
- Do not leave user-relevant durable state only in chat.
