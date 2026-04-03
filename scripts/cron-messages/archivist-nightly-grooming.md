Run nightly knowledge graph grooming. Follow this procedure:

## Step 1: Find new memories to graph-link

Search Qdrant for recent memories that mention entities. Use queries like:
- `[real] [fact] new repository`
- `[real] [fact] new project`
- `[real] [fact] new service`
- `[real] [decision]` (decisions often create or change relationships)
- `[real] [incident]` (incidents may reveal dependencies)

For each relevant memory, check if the entities mentioned already exist in the graph. If not, create them following the canonical schema. Connect them with appropriate relationships.

## Step 2: Link memories to graph entities

For Qdrant memories that describe important decisions, conventions, or facts about known entities, create or update `MemoryEntry` nodes in the graph with the Qdrant ID and connect them to the relevant entity nodes.

## Step 3: Check for stale or orphaned structure

Traverse the graph for nodes with no relationships (orphans) or relationships that may be outdated based on recent memories. Flag anything suspicious but do not delete — log it to `/Projects/ai-homebase/archivist-grooming-log.md`.

## Step 4: Update schema docs if needed

If you added new labels, relationship types, or changed the canonical schema, update `/Projects/ai-homebase/knowledge-graph-schema.md`.

## Step 5: Log what you did

Append a brief summary to `/Projects/ai-homebase/archivist-grooming-log.md` with today's date, what you found, what you changed, and any issues.

Use `require('neo4j-driver')` for all Bolt connections. Do not use mgconsole. Keep changes conservative — prefer updating existing structure over creating new schema patterns. If the grooming finds nothing significant, just log "no changes" and finish quickly.
