# Archivist Weekly Grooming

## Trigger

- Source: weekly cron prompt
- Session type: archivist standing main session with a scheduled system-event prompt

## Guaranteed Starting Context

- archivist system prompt files
- available archivist workspace skills and local query/qdrant helper files
- current session is not a heartbeat and is not an isolated cron context

## Context That Must Be Fetched Explicitly

- `state/grooming-checkpoint.json`
- `groom-knowledge-graph` skill
- any changed Nextcloud surfaces discovered from the checkpoint window and registries
- Qdrant candidates and Memgraph query results produced during the run

## Flow

```mermaid
flowchart TD
    G[Weekly grooming prompt] --> A0[Load groom-knowledge-graph]
    A0 --> A1[Read grooming checkpoint]
    A1 --> A2[Choose bounded delta window]
    A2 --> A3[Scan Qdrant candidates and changed Nextcloud surfaces]
    A3 --> A4[Link or groom in Memgraph first]
    A4 --> A5[Annotate Qdrant graph payloads]
    A5 --> A6[Append grooming log row]
    A6 --> A7{Run completed safely?}
    A7 -->|yes| A8[Advance checkpoint]
    A7 -->|no| A9[Leave successful checkpoint fields unchanged]
```

## Step Notes

1. Archivist must use the real skill name `groom-knowledge-graph`.
2. The checkpoint is runtime state and must be read before any delta decision is made.
3. The grooming pass stays bounded unless a request explicitly asks for historical backfill.
4. Memgraph updates happen before Qdrant graph-link annotations.

## Escalation And Output

- durable outputs: Nextcloud grooming log, Memgraph links, Qdrant graph payloads, checkpoint update
- if the run cannot complete safely, record the issue and do not advance successful checkpoint timestamps

## Prompt-Writing Pitfalls

- do not reference nonexistent skill names
- do not imply that Nextcloud docs are the primary truth source for archivist
- do not tell archivist to run an unbounded historical pass by default
