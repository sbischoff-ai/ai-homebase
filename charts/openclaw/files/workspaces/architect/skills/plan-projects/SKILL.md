---
name: plan-projects
description: Use when creating or updating durable project planning artifacts in Nextcloud, including specs, decisions, and planning trackers.
---

# Nextcloud Project Planning

Architect owns durable planning artifacts in Nextcloud.

## Default Outputs

For a project slug, prefer:
- Nextcloud `/Projects/<slug>/plan.md`
- Nextcloud `/Projects/<slug>/spec.md`
- Nextcloud `/Projects/<slug>/decisions.md`
- Nextcloud `/Projects/<slug>/status.md` when the user or other agents need a compact current-state artifact

Use a table only when the state is truly structured and repeatedly updated, such as:
- work-item trackers
- worker-definition matrices
- dependency inventories

## Procedure

1. Read `CURRENT.md`, `SURFACES.md`, the latest local daily note, and only the relevant shared Nextcloud `/Desk/` entries before planning.
2. Treat Nextcloud paths as remote paths.
3. Check whether Nextcloud `/Projects/<slug>/` already exists before creating new planning artifacts.
4. Reuse and update existing project docs instead of scattering multiple overlapping files.
5. Keep private rough decomposition in workspace files until it becomes shared planning material.
6. Write one decision-complete artifact per planning pass.
7. Use Nextcloud `/Projects/<slug>/status.md` when other agents or the user need a compact current-state artifact instead of inventing extra scratch files.
8. If you create a recurring shared planning surface outside Nextcloud `/Projects/<slug>/`, register it in Nextcloud `/Desk/index.md` with purpose, steward, and read trigger.
9. Promote stable planning outputs into shareable locations.
10. Store distilled decisions in Qdrant with `project`, `tags`, and `nc_refs`.

## Boundaries

- Main coordinates the user; architect authors the durable planning artifact.
- Do not turn lightweight coordination into an overbuilt project tree.
- Do not turn Nextcloud `/Desk/` into a planning archive; it is for bounded continuity and discovery.
- Do not recreate a generic shared scratchpad folder when workspace files or Qdrant already fit the job better.
