---
name: update-implementation-notes
description: Use when reading governing specs from Nextcloud or writing durable implementation notes after non-obvious implementation work.
---

# Nextcloud Implementation Handoff

Coder uses Nextcloud for durable implementation context, not code storage.

## Read From Nextcloud

- governing plan or spec
- runbooks
- deployment notes
- prior implementation summaries

## Write To Nextcloud

After non-obvious implementation work, prefer:
- Nextcloud `/Projects/<slug>/decisions.md` for durable technical decisions
- Nextcloud `/Projects/<slug>/runbook.md` or equivalent for operator steps
- Nextcloud `/Projects/<slug>/implementation-summary.md` when a compact summary helps later work
- a durable gap note when architect follow-up is needed

Keep private debugging notes local until they become a reusable lesson, a durable decision, or a summary the user or another agent will need later.
Keep short-term restart notes in the repo, not in a persistent OpenClaw desk.

## Do Not Write

- code
- patch dumps
- raw test logs unless they are the durable artifact the user actually needs

## Procedure

1. Read the governing Nextcloud artifact before implementing when one exists.
2. After implementation, write only the durable technical summary that future work needs.
3. If the implementation reveals unresolved design debt or a missing durable decision, record the gap so architect can follow up.
4. If another agent or the user will need to rediscover the artifact later, make sure the summary includes enough path or slug detail for Nextcloud `/Desk/index.md` or `nc_refs` to point back to it.
5. Store a Qdrant summary with `project`, `tags`, and `nc_refs` when the outcome establishes a reusable convention.
