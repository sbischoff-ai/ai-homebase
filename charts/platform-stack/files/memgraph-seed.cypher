// === Core entities ===

MERGE (project:Entity:Project {slug: 'ai-homebase'})
ON CREATE SET project.name = 'ai-homebase',
              project.domain = 'real',
              project.kind = 'platform',
              project.status = 'active';

MERGE (user:Entity:Person {slug: 'user'})
ON CREATE SET user.name = 'User',
              user.domain = 'real',
              user.kind = 'owner';

// === Services ===

MERGE (openclaw:Entity:Service {slug: 'openclaw'})
ON CREATE SET openclaw.name = 'OpenClaw',
              openclaw.domain = 'real',
              openclaw.kind = 'agent-runtime';

MERGE (nextcloud:Entity:Service {slug: 'nextcloud'})
ON CREATE SET nextcloud.name = 'Nextcloud',
              nextcloud.domain = 'real',
              nextcloud.kind = 'knowledge-store';

MERGE (qdrant:Entity:Service {slug: 'qdrant'})
ON CREATE SET qdrant.name = 'Qdrant',
              qdrant.domain = 'real',
              qdrant.kind = 'vector-memory';

MERGE (memgraph:Entity:Service {slug: 'memgraph'})
ON CREATE SET memgraph.name = 'Memgraph',
              memgraph.domain = 'real',
              memgraph.kind = 'graph-memory';

MERGE (gitea:Entity:Service {slug: 'gitea'})
ON CREATE SET gitea.name = 'Gitea',
              gitea.domain = 'real',
              gitea.kind = 'source-control';

MERGE (argocd:Entity:Service {slug: 'argocd'})
ON CREATE SET argocd.name = 'Argo CD',
              argocd.domain = 'real',
              argocd.kind = 'gitops';

MERGE (registry:Entity:Service {slug: 'registry'})
ON CREATE SET registry.name = 'Registry',
              registry.domain = 'real',
              registry.kind = 'artifact-store';

// === Agents ===

MERGE (main:Entity:Agent {slug: 'main'})
ON CREATE SET main.name = 'main',
              main.domain = 'real',
              main.kind = 'orchestrator';

MERGE (architect:Entity:Agent {slug: 'architect'})
ON CREATE SET architect.name = 'architect',
              architect.domain = 'real',
              architect.kind = 'planner';

MERGE (coder:Entity:Agent {slug: 'coder'})
ON CREATE SET coder.name = 'coder',
              coder.domain = 'real',
              coder.kind = 'implementer';

MERGE (watchdog:Entity:Agent {slug: 'watchdog'})
ON CREATE SET watchdog.name = 'watchdog',
              watchdog.domain = 'real',
              watchdog.kind = 'monitor';

MERGE (archivist:Entity:Agent {slug: 'archivist'})
ON CREATE SET archivist.name = 'archivist',
              archivist.domain = 'real',
              archivist.kind = 'curator';

MERGE (auditor:Entity:Agent {slug: 'auditor'})
ON CREATE SET auditor.name = 'auditor',
              auditor.domain = 'real',
              auditor.kind = 'reviewer';

// === Repositories ===

MERGE (gitopsRepo:Entity:Work {slug: 'cluster-gitops'})
ON CREATE SET gitopsRepo.name = 'cluster-gitops',
              gitopsRepo.domain = 'real',
              gitopsRepo.kind = 'repository';

MERGE (sandboxRepo:Entity:Work {slug: 'openclaw-sandbox-images'})
ON CREATE SET sandboxRepo.name = 'openclaw-sandbox-images',
              sandboxRepo.domain = 'real',
              sandboxRepo.kind = 'repository';

// === Relationships ===

MATCH (project:Entity:Project {slug: 'ai-homebase'})
MATCH (user:Entity:Person {slug: 'user'})
MATCH (openclaw:Entity:Service {slug: 'openclaw'})
MATCH (nextcloud:Entity:Service {slug: 'nextcloud'})
MATCH (qdrant:Entity:Service {slug: 'qdrant'})
MATCH (memgraph:Entity:Service {slug: 'memgraph'})
MATCH (gitea:Entity:Service {slug: 'gitea'})
MATCH (argocd:Entity:Service {slug: 'argocd'})
MATCH (registry:Entity:Service {slug: 'registry'})
MATCH (main:Entity:Agent {slug: 'main'})
MATCH (architect:Entity:Agent {slug: 'architect'})
MATCH (coder:Entity:Agent {slug: 'coder'})
MATCH (watchdog:Entity:Agent {slug: 'watchdog'})
MATCH (archivist:Entity:Agent {slug: 'archivist'})
MATCH (auditor:Entity:Agent {slug: 'auditor'})
MATCH (gitopsRepo:Entity:Work {slug: 'cluster-gitops'})
MATCH (sandboxRepo:Entity:Work {slug: 'openclaw-sandbox-images'})

// User owns the project
MERGE (project)-[:HAS_PART {role: 'owner'}]->(user)

// Project uses services
MERGE (project)-[:HAS_PART {kind: 'service'}]->(openclaw)
MERGE (project)-[:HAS_PART {kind: 'service'}]->(nextcloud)
MERGE (project)-[:HAS_PART {kind: 'service'}]->(qdrant)
MERGE (project)-[:HAS_PART {kind: 'service'}]->(memgraph)
MERGE (project)-[:HAS_PART {kind: 'service'}]->(gitea)
MERGE (project)-[:HAS_PART {kind: 'service'}]->(argocd)
MERGE (project)-[:HAS_PART {kind: 'service'}]->(registry)
MERGE (project)-[:HAS_PART {kind: 'artifact'}]->(gitopsRepo)
MERGE (project)-[:HAS_PART {kind: 'artifact'}]->(sandboxRepo)

// Agents are part of OpenClaw
MERGE (openclaw)-[:HAS_PART {kind: 'agent'}]->(main)
MERGE (openclaw)-[:HAS_PART {kind: 'agent'}]->(architect)
MERGE (openclaw)-[:HAS_PART {kind: 'agent'}]->(coder)
MERGE (openclaw)-[:HAS_PART {kind: 'agent'}]->(watchdog)
MERGE (openclaw)-[:HAS_PART {kind: 'agent'}]->(archivist)
MERGE (openclaw)-[:HAS_PART {kind: 'agent'}]->(auditor)

// Archivist manages graph and memory services
MERGE (archivist)-[:INFLUENCES {kind: 'curates', context: 'graph structure'}]->(memgraph)
MERGE (archivist)-[:INFLUENCES {kind: 'grooms', context: 'memory consolidation'}]->(qdrant);
