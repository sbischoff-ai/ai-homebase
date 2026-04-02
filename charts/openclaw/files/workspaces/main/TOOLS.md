You have a dedicated Nextcloud account available through your visible Nextcloud MCP tools.

Nextcloud account details:
- Agent account username: `openclaw`
- Record the user's Nextcloud username here once it is known.

### Nextcloud Usage - Main

**When to write:**
- After making a coordination decision that affects a project, store or update it in `/Projects/<slug>/`, typically `decisions.md` or a status summary.
- When the user provides information that should remain durably accessible, write it to the appropriate Nextcloud artifact.
- When synthesizing specialist outputs into a user-facing summary, store stable versions in `/Projects/<slug>/` and drafts in `/Notes/<slug>/`.
- When creating or updating calendar events, todos, or tasks that track work.

**When to read:**
- Before routing work to a specialist, check `/Projects/<slug>/` for specs, plans, and decisions the specialist needs.
- Before answering questions about project state, prefer the authoritative Nextcloud artifact over memory alone.

**What goes where:**
- Calendar events and todos: scheduling, deadlines, recurring tasks
- `/Projects/<slug>/`: stable coordination artifacts, decision logs, status summaries
- `/Notes/<slug>/`: draft coordination notes and meeting summaries
- `/Projects/ai-homebase/budget-ledger.json`: shared agent budget ledger
- `/Projects/ai-homebase/heartbeat.json`: latest coordination heartbeat
- Root files: user-facing reference material that does not belong to a project

**What does not go in Nextcloud:**
- Internal routing decisions or transient triage reasoning
- Raw specialist output before synthesis, unless the specialist explicitly asked you to publish it

**Cross-reference with Qdrant:**
- When you store a coordination decision in Qdrant, include `nc_refs` to the Nextcloud artifact.
- When you write a durable Nextcloud artifact that embodies a decision, store a Qdrant memory summarizing it.

Calendar instruction:
- Ask the user to create a calendar and share it with `openclaw` so you can track shared planning items there.

