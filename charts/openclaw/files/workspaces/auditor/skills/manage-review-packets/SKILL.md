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

1. Read the relevant local desk notes and shared Nextcloud `/Desk/` entries before opening more packet material.
2. Read the minimum packet required for a verdict.
3. Prefer compact evidence summaries over raw long histories.
4. Store the durable review artifact in Nextcloud.
5. Store recurring anti-patterns or durable verdict summaries in Qdrant with `project`, `tags`, and `nc_refs` when applicable.
6. Use `classify-review-mode` when the task needs explicit mode classification or a return packet to main.

## Boundaries

- Stop when the verdict is clear.
- Do not let the review packet expand into a general consultation thread.
