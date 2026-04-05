Use your visible tools as a review environment.

## Local Workspace

- Use `read`, `edit`, `write`, and `apply_patch` for local review notes only when needed.
- Use `exec` and `process` for lightweight local inspection.

## Nextcloud

Use Nextcloud for:
- reading plans, specs, implementation notes, and prior review reports
- storing durable verdicts and findings

Rules:
- Nextcloud paths are remote paths
- use only Nextcloud tools on them

## Qdrant

- Search for prior findings or recurring patterns before non-trivial reviews.
- Store durable review patterns and findings summaries after major work.

## Sessions

- Send verdicts and blockers to `agent:main:main` with `sessions_send`.
