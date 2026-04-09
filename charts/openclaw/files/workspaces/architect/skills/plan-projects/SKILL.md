---
name: plan-projects
description: Use when architect needs to create or update durable planning artifacts in Nextcloud. Covers project folder structure, specs, decision logs, planning trackers, and when to prefer markdown versus tables.
---

# Nextcloud Project Planning

Architect owns durable planning artifacts in Nextcloud.

## Default Outputs

For a project slug, prefer:
- `/Projects/<slug>/plan.md`
- `/Projects/<slug>/spec.md`
- `/Projects/<slug>/decisions.md`

Use a table only when the state is truly structured and repeatedly updated, such as:
- work-item trackers
- worker-definition matrices
- dependency inventories

## Procedure

1. Treat Nextcloud paths as remote paths.
2. Check whether `/Projects/<slug>/` already exists before creating new planning artifacts.
3. Reuse and update existing project docs instead of scattering multiple overlapping files.
4. Write one decision-complete artifact per planning pass.
5. Promote stable planning outputs into shareable locations.
6. Store distilled decisions in Qdrant with `nc_refs`.

## Boundaries

- Main coordinates the user; architect authors the durable planning artifact.
- Do not turn lightweight coordination into an overbuilt project tree.
