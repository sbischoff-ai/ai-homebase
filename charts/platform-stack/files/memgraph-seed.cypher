MERGE (project:Entity:Project:System {slug: 'ai-homebase'})
ON CREATE SET project.name = 'ai-homebase',
              project.domain = 'real',
              project.kind = 'platform';

MERGE (user:Entity:Person:User {slug: 'user'})
ON CREATE SET user.name = 'User',
              user.domain = 'real';

MERGE (openclaw:Entity:Service:System {slug: 'openclaw'})
ON CREATE SET openclaw.name = 'OpenClaw',
              openclaw.category = 'agent-runtime';

MERGE (nextcloud:Entity:Service:System {slug: 'nextcloud'})
ON CREATE SET nextcloud.name = 'Nextcloud',
              nextcloud.category = 'knowledge-store';

MERGE (qdrant:Entity:Service:System {slug: 'qdrant'})
ON CREATE SET qdrant.name = 'Qdrant',
              qdrant.category = 'vector-memory';

MERGE (memgraph:Entity:Service:System {slug: 'memgraph'})
ON CREATE SET memgraph.name = 'Memgraph',
              memgraph.category = 'graph-memory';

MERGE (memgraphLab:Entity:Service:System {slug: 'memgraph-lab'})
ON CREATE SET memgraphLab.name = 'Memgraph Lab',
              memgraphLab.category = 'graph-ui';

MERGE (gitea:Entity:Service:System {slug: 'gitea'})
ON CREATE SET gitea.name = 'Gitea',
              gitea.category = 'source-control';

MERGE (argocd:Entity:Service:System {slug: 'argocd'})
ON CREATE SET argocd.name = 'Argo CD',
              argocd.category = 'gitops';

MERGE (registry:Entity:Service:System {slug: 'registry'})
ON CREATE SET registry.name = 'Registry',
              registry.category = 'artifact-store';

MERGE (main:Entity:Agent:Person {slug: 'main'})
ON CREATE SET main.name = 'main',
              main.role = 'orchestrator';

MERGE (architect:Entity:Agent:Person {slug: 'architect'})
ON CREATE SET architect.name = 'architect',
              architect.role = 'planner';

MERGE (coder:Entity:Agent:Person {slug: 'coder'})
ON CREATE SET coder.name = 'coder',
              coder.role = 'implementer';

MERGE (watchdog:Entity:Agent:Person {slug: 'watchdog'})
ON CREATE SET watchdog.name = 'watchdog',
              watchdog.role = 'monitor';

MERGE (archivist:Entity:Agent:Person {slug: 'archivist'})
ON CREATE SET archivist.name = 'archivist',
              archivist.role = 'knowledge-graph-curator';

MERGE (gitopsRepo:Entity:Repository:System {slug: 'cluster-gitops'})
ON CREATE SET gitopsRepo.name = 'cluster-gitops',
              gitopsRepo.kind = 'gitops';

MERGE (sandboxRepo:Entity:Repository:System {slug: 'openclaw-sandbox-images'})
ON CREATE SET sandboxRepo.name = 'openclaw-sandbox-images',
              sandboxRepo.kind = 'sandbox-images';

MATCH (project:Entity:Project:System {slug: 'ai-homebase'})
MATCH (user:Entity:Person:User {slug: 'user'})
MATCH (openclaw:Entity:Service:System {slug: 'openclaw'})
MATCH (nextcloud:Entity:Service:System {slug: 'nextcloud'})
MATCH (qdrant:Entity:Service:System {slug: 'qdrant'})
MATCH (memgraph:Entity:Service:System {slug: 'memgraph'})
MATCH (memgraphLab:Entity:Service:System {slug: 'memgraph-lab'})
MATCH (gitea:Entity:Service:System {slug: 'gitea'})
MATCH (argocd:Entity:Service:System {slug: 'argocd'})
MATCH (registry:Entity:Service:System {slug: 'registry'})
MATCH (main:Entity:Agent:Person {slug: 'main'})
MATCH (architect:Entity:Agent:Person {slug: 'architect'})
MATCH (coder:Entity:Agent:Person {slug: 'coder'})
MATCH (watchdog:Entity:Agent:Person {slug: 'watchdog'})
MATCH (archivist:Entity:Agent:Person {slug: 'archivist'})
MATCH (gitopsRepo:Entity:Repository:System {slug: 'cluster-gitops'})
MATCH (sandboxRepo:Entity:Repository:System {slug: 'openclaw-sandbox-images'})
MERGE (project)-[:HAS_MEMBER]->(user)
MERGE (project)-[:USES]->(openclaw)
MERGE (project)-[:USES]->(nextcloud)
MERGE (project)-[:USES]->(qdrant)
MERGE (project)-[:USES]->(memgraph)
MERGE (project)-[:USES]->(memgraphLab)
MERGE (project)-[:USES]->(gitea)
MERGE (project)-[:USES]->(argocd)
MERGE (project)-[:USES]->(registry)
MERGE (project)-[:USES]->(gitopsRepo)
MERGE (project)-[:USES]->(sandboxRepo)
MERGE (main)-[:PART_OF]->(openclaw)
MERGE (architect)-[:PART_OF]->(openclaw)
MERGE (coder)-[:PART_OF]->(openclaw)
MERGE (watchdog)-[:PART_OF]->(openclaw)
MERGE (archivist)-[:PART_OF]->(openclaw)
MERGE (archivist)-[:MANAGES {role: 'graph-curation'}]->(memgraph)
MERGE (archivist)-[:MANAGES {role: 'memory-grooming'}]->(qdrant)
MERGE (archivist)-[:MANAGES {role: 'schema-maintenance'}]->(memgraph)
MERGE (memgraphLab)-[:USES {role: 'graph-visualization'}]->(memgraph)
