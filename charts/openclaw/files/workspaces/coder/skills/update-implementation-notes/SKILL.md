---
name: update-implementation-notes
description: Use when coder needs to read governing specs from Nextcloud or write durable implementation notes back. Covers what belongs in Nextcloud, what does not, and the standard handoff artifacts after non-obvious implementation work.
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
- `/Projects/<slug>/decisions.md` for durable technical decisions
- `/Projects/<slug>/runbook.md` or equivalent for operator steps
- `/Projects/<slug>/implementation-summary.md` when a compact summary helps later work
- a durable gap note when architect follow-up is needed

Keep private debugging notes local until they become a reusable lesson, a durable decision, or a summary the user or another agent will need later.

## Do Not Write

- code
- patch dumps
- raw test logs unless they are the durable artifact the user actually needs

## Procedure

1. Read the governing Nextcloud artifact before implementing when one exists.
2. After implementation, write only the durable technical summary that future work needs.
3. If the implementation reveals unresolved design debt or a missing durable decision, record the gap so architect can follow up.
4. Store a Qdrant summary with `nc_refs` when the outcome establishes a reusable convention.
