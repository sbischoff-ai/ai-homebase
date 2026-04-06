# Multi-Agent Topology

## Three-Layer Architecture

Top layer: intelligence and validation.

- `architect` (Claude Sonnet 4.6) and `auditor` (Claude Opus 4.6) are general-purpose frontier thinkers.
- Their scope is any domain that needs deep reasoning, design, or validation, not just cluster or coding work.
- They produce execution-ready specifications, plans, worker definitions, and structured validation verdicts.
- Their outputs must be unambiguous and executable without interpretation.

Middle layer: coordination, state, and integration.

- `main` (GPT-4.1), `archivist` (GPT-5.4 Mini), and `coder` (Claude Sonnet 4.6 plus Codex CLI on GPT-5.4 Mini) handle variability, integration, shared state, and complex implementation.
- These agents have meaningful reasoning capacity.
- They do not replace top-layer reasoning, but they are not purely mechanical either.

Bottom layer: execution.

- `watchdog` (GPT-5.4 Nano) and worker agents (GPT-5.4 Mini or Nano) execute predefined workflows repeatedly and cheaply.
- They do not make independent creative or strategic decisions.
- They escalate when ambiguity appears.

Design principle:
- intelligence is concentrated at the top and amortized through cheap execution at the bottom.
- worker agents should consume the bulk of total system tokens.

## Agent Roster

- `main` | middle | GPT-4.1 | user-facing coordinator, task router, budget manager
- `architect` | top | Claude Sonnet 4.6 | general-purpose planner, designer, specification author, worker agent designer
- `coder` | middle | Claude Sonnet 4.6 + Codex CLI with GPT-5.4 Mini | implementation executor, GitOps, Codex delegation
- `archivist` | middle | GPT-5.4 Mini | knowledge graph curator, cross-agent memory steward, structured recall service
- `watchdog` | bottom | GPT-5.4 Nano | lightweight monitoring, heartbeat checks, triage
- `auditor` | top | Claude Opus 4.6 | general-purpose quality reviewer, validation gate for high-stakes outputs

Standing specialists:
- `main`, `architect`, `coder`, `archivist`, `watchdog`, and `auditor` are part of the standard standing topology.
- `auditor` is expected to be invoked sparsely, but it is still part of the standing specialist set.

Worker agents are not standing agents. They are instantiated on demand from architect-defined worker definitions and configured by `main`.

## Controlled Self-Improvement Loop

- `main` turns raw user intent into routed work.
- `architect` produces execution-ready specs, plans, and worker definitions.
- `coder` mutates repositories, runtime images, and deployment definitions.
- Gitea, the registry, and Argo CD carry those mutations toward the running cluster.
- `watchdog` detects drift, recurring failures, and weak spots in operation.
- `auditor` reviews finished work and proposes improvements, optimizations, and automation opportunities.
- `archivist` preserves decisions, relationships, and cross-project structure so the system can reason from durable context instead of isolated chat history.

## Coordination Model

- `main` receives user requests and classifies them.
- `main` applies the current budget policy from `/Projects/ai-homebase/budget-policy.md` when making routine delegation decisions.
- Small tasks inside `main`'s domain are handled directly.
- Design, planning, and specification work goes to `architect`.
- `architect` returns actionable work items to `main`.
- `main` routes those items to `coder`, `archivist`, `watchdog`, worker agents, or itself.
- High-stakes outputs go to `auditor` for validation before delivery.
- `archivist` serves as a structured recall service; any agent can request graph-backed context through `main` when Qdrant semantic search is insufficient.

## Worker Agents

- Worker agents are domain-specific execution units designed by `architect`.
- Each worker has an execution plan, reference documentation, a scheduling model, and escalation rules defined before instantiation.
- Workers use GPT-5.4 Nano or GPT-5.4 Mini depending on task complexity.
- Workers must not redesign workflows, make strategic decisions, or interpret ambiguous instructions.
- Workers escalate exclusively to `main`.
- Example worker types: `accountant`, `mail_clerk`, `reporter`, `market_tracker`, `habit_helper`

## System Invariants

- Intelligence resides at the top; workers do not compensate for poor specifications.
- The middle layer handles variability; it does not replace top-layer reasoning.
- `archivist` is the graph of record; Qdrant is the semantic search index; they complement each other.
- `main` is the only agent that spawns sessions or instantiates workers.
- All escalations route through `main`.
- The deployment gate stays outside the agents: cluster-state mutation is prepared by agents but applied through reviewed GitOps and manual Argo CD sync.
