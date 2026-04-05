---
name: memory_and_heartbeat
description: Use when main needs to decide what durable facts belong in Qdrant or when to update the shared heartbeat file. Covers memory triggers, nc_refs, and the exact heartbeat write shape.
---

# Memory And Heartbeat

Use this skill after meaningful coordination work.

## Search Trigger

Search Qdrant before non-trivial coordination, especially when prior context, preferences, or project history may matter.

## Store Triggers

Store a Qdrant memory when:
- a durable user preference becomes clear
- a project-level decision is made
- a handoff creates or changes a durable artifact
- a stack-level operating rule changes

When a memory corresponds to a Nextcloud artifact, include `nc_refs`.

## Heartbeat

After meaningful coordination work, follow `HEARTBEAT.md`.
Write `/Projects/ai-homebase/heartbeat.json` with:
`{"lastActivity":"ISO-8601","agent":"main","status":"ok"}`

## Boundaries

- Do not treat local retrieval hints as the primary long-term memory system.
- Do not leave user-relevant durable state only in chat.
