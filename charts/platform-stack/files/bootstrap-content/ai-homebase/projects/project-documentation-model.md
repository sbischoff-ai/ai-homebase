# Project Documentation Model

Every project should use the same separation of concerns:

- `/Projects/<project-slug>/` is durable, curated, and long-term
- `/Notes/<project-slug>/` is temporary, iterative, and short-term

Durable artifacts belong in `/Projects/`, for example:
- `spec.md`
- `architecture.md`
- `plan.md`
- `decisions.md`

Working notes belong in `/Notes/`, for example:
- brainstorming
- planning scratchpads
- meeting notes
- task breakdown drafts

Promotion rule:
- if something becomes important or stable, move it from `/Notes/` into `/Projects/`.
