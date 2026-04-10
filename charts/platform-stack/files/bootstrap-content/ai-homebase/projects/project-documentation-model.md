# Project Documentation Model

Every project should use the same default storage model:

- `/Projects/<project-slug>/` is the default durable project home
- additional Nextcloud folders may be created later when a project truly benefits from them

Storage hierarchy from most permissive to most curated:

- local workspace files: private WIP, rough drafts, self-notes, temporary working state
- Qdrant: shared quick recall, decisions, conventions, handoff context, and other note-like memories worth finding later
- Memgraph through `archivist`: structural entities, relationships, and promoted graph-linked memory
- Nextcloud: curated shared artifacts, user collaboration surfaces, and durable project records

Durable artifacts belong in `/Projects/`, for example:
- `spec.md`
- `architecture.md`
- `plan.md`
- `decisions.md`

Use local workspace files instead of a shared Nextcloud scratchpad when the material is still private, provisional, or only useful to one agent while thinking.
Store shared quick notes in Qdrant when they should shape later work but do not need a user-facing document yet.
Drafts may also live in `/Projects/` when they are part of the project's shared working record or the user should be able to collaborate on them there.

If agents create additional Nextcloud folders later, they should do so intentionally, document the purpose, and avoid recreating a generic catch-all notes bucket.
