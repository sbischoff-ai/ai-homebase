---
name: manage-review-packets
description: Use when auditor needs to read or write durable review artifacts in Nextcloud. Covers review packet intake, evidence selection, durable findings storage, and keeping the packet compact.
---

# Nextcloud Review Packets

Auditor uses Nextcloud for review packets and durable findings.

## Inputs

Read only what the verdict needs:
- plans and specs
- implementation notes
- prior review reports
- explicit evidence summaries

## Outputs

Write durable review artifacts such as:
- review packet summaries
- verdict documents
- durable findings with evidence references

## Procedure

1. Read the minimum packet required for a verdict.
2. Prefer compact evidence summaries over raw long histories.
3. Store the durable review artifact in Nextcloud.
4. Store recurring anti-patterns or durable verdict summaries in Qdrant with `nc_refs` when applicable.
5. Use `classify-review-mode` when the task needs explicit mode classification or a return packet to main.

## Boundaries

- Stop when the verdict is clear.
- Do not let the review packet expand into a general consultation thread.
